//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import <objc/runtime.h>

@interface NSObject ()
@property (readonly) NSMutableSet *RACKVOTrampolines;
@end


@interface RACKVOTrampoline : NSObject

@property (nonatomic, copy) void (^block)(id blockSelf, NSDictionary *change);
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, unsafe_unretained) NSObject *observable;
@property (nonatomic, unsafe_unretained) NSObject *target;

- (void)startObservingOnObject:(NSObject *)object options:(NSKeyValueObservingOptions)options;
- (void)stopObserving;

@end

@implementation RACKVOTrampoline

static char RACKVOWrapperContext;

- (void)dealloc {
	[self stopObserving];
}

- (void)observeValueForKeyPath:(NSString *)triggeredKeyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context == &RACKVOWrapperContext) {
        if(self.queue == nil) {
            self.block(self.target, change);
            return;
        }
		
		// We want to keep all these guys around until we've delivered the notification block. So this.
		RACKVOTrampoline *capturedSelf = self;
		NSObject *strongTarget = self.target;
        [self.queue addOperationWithBlock:^{
            capturedSelf.block(strongTarget, change);
        }];
    } else {
        [super observeValueForKeyPath:triggeredKeyPath ofObject:object change:change context:context];
    }
}


#pragma mark API

@synthesize block;
@synthesize keyPath;
@synthesize queue;
@synthesize observable;
@synthesize target;

- (void)startObservingOnObject:(NSObject *)object options:(NSKeyValueObservingOptions)options {
	self.observable = object;
	[self.observable addObserver:self forKeyPath:self.keyPath options:options context:&RACKVOWrapperContext];
    
    [self.observable.RACKVOTrampolines addObject:self];
}

- (void)stopObserving {
	[self.observable removeObserver:self forKeyPath:self.keyPath];
	self.observable = nil;
	
    [self.observable.RACKVOTrampolines removeObject:self];
	self.observable = nil;
}

@end


static void *RACKVOTrampolinesKey = &RACKVOTrampolinesKey;

static NSMutableDictionary *swizzledClasses = nil;

void Swizzle(Class c, SEL orig, SEL new)
{
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
		method_exchangeImplementations(origMethod, newMethod);
}

@implementation NSObject (RACKVOWrapper)

+ (void)load {
	swizzledClasses = [[NSMutableDictionary alloc] init];
}

- (void)rac_customDealloc {
	objc_setAssociatedObject(self, RACKVOTrampolinesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_customDealloc];
}

- (id)rac_addObserver:(NSObject *)target forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id target, NSDictionary *change))block {
	@synchronized(swizzledClasses) {
		if([swizzledClasses objectForKey:NSStringFromClass([self class])] == nil) {
			Swizzle([self class], NSSelectorFromString(@"dealloc"), @selector(rac_customDealloc));
			[swizzledClasses setObject:[NSNull null] forKey:NSStringFromClass([self class])];
		}
	}
	
	RACKVOTrampoline *trampoline = [[RACKVOTrampoline alloc] init];
	trampoline.block = block;
	trampoline.keyPath = keyPath;
	trampoline.queue = queue;
	trampoline.target = target;
	[trampoline startObservingOnObject:self options:options];
	return trampoline;
}

- (BOOL)rac_removeObserverWithIdentifier:(id)identifier {
	return [self rac_removeObserverTrampoline:identifier];
}

- (BOOL)rac_removeObserverTrampoline:(RACKVOTrampoline *)trampoline {
	if(trampoline.observable != self) return NO;
	
	[trampoline stopObserving];

	return YES;
}

- (NSMutableSet *)RACKVOTrampolines {
    @synchronized(self) {
        NSMutableSet *trampolines = objc_getAssociatedObject(self, RACKVOTrampolinesKey);
        if(trampolines == nil) {
            trampolines = [NSMutableSet set];
            objc_setAssociatedObject(self, RACKVOTrampolinesKey, trampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        return trampolines;
    }
}

@end
