//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "RACSwizzling.h"
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
        if(self.queue == nil || self.queue == [NSOperationQueue currentQueue]) {
            self.block(self.target, change);
        } else {
			[self.queue addOperationWithBlock:^{
				self.block(self.target, change);
			}];
		}
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
    
    [self.target.RACKVOTrampolines addObject:self];
}

- (void)stopObserving {
	[self.observable removeObserver:self forKeyPath:self.keyPath];
	self.observable = nil;
	
    [self.target.RACKVOTrampolines removeObject:self];
	self.target = nil;
}

@end


static void *RACKVOTrampolinesKey = &RACKVOTrampolinesKey;

static NSMutableDictionary *swizzledClasses = nil;

@implementation NSObject (RACKVOWrapper)

+ (void)load {
	swizzledClasses = [[NSMutableDictionary alloc] init];
}

- (void)rac_customDealloc {
	// If we're currently delivering a KVO callback then niling the trampoline set might not dealloc the trampoline and therefore make them be dealloc'd. So we need to manually stop observing on all of them as well.
	for(RACKVOTrampoline *trampoline in [self.RACKVOTrampolines copy]) {
		[trampoline stopObserving];
	}
	
	objc_setAssociatedObject(self, RACKVOTrampolinesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_customDealloc];
}

- (id)rac_addObserver:(NSObject *)target forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id target, NSDictionary *change))block {
	// We gotta swizzle dealloc to make sure no KVO callbacks are sent once we've started dealloc'ing.
	@synchronized(swizzledClasses) {
		Class classToSwizzle = [target class];
		NSString *classKey = NSStringFromClass(classToSwizzle);
		if([swizzledClasses objectForKey:classKey] == nil) {
			RACSwizzle(classToSwizzle, NSSelectorFromString(@"dealloc"), @selector(rac_customDealloc));
			[swizzledClasses setObject:[NSNull null] forKey:classKey];
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
	if(trampoline.target != self) return NO;
	
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
