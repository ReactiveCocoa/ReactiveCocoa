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
@property (readonly) NSMutableSet *RACKVOObservingTrampolines;
@property (readonly) NSMutableSet *RACKVOTargetTrampolines;
@end


@interface RACKVOTrampoline : NSObject

@property (nonatomic, copy) void (^block)(id blockSelf, NSDictionary *change);
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, unsafe_unretained) NSObject *observing;
@property (nonatomic, unsafe_unretained) NSObject *target;

@end

@implementation RACKVOTrampoline

static char RACKVOWrapperContext;

- (void)dealloc {
	[self stopObserving];
}

- (void)observeValueForKeyPath:(NSString *)triggeredKeyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if(context == &RACKVOWrapperContext) {
		if(self.queue == nil || self.queue == [NSOperationQueue currentQueue]) {
			if(self.block != NULL) self.block(self.target, change);
        } else {
			[self.queue addOperationWithBlock:^{
				if(self.block != NULL) self.block(self.target, change);
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
@synthesize observing;
@synthesize target;

- (void)startObservingObject:(NSObject *)object options:(NSKeyValueObservingOptions)options {
	self.observing = object;
	[self.observing addObserver:self forKeyPath:self.keyPath options:options context:&RACKVOWrapperContext];
    [self.observing.RACKVOObservingTrampolines addObject:self];
	
	[self.target.RACKVOTargetTrampolines addObject:self];
}

- (void)stopObserving {
	[self.observing removeObserver:self forKeyPath:self.keyPath];
	[self.observing.RACKVOObservingTrampolines removeObject:self];
	self.observing = nil;
	
	[self.target.RACKVOTargetTrampolines removeObject:self];
	self.target = nil;
	
	self.block = nil;
}

@end


static void *RACKVOObservingTrampolinesKey = &RACKVOObservingTrampolinesKey;
static void *RACKVOTargetTrampolinesKey = &RACKVOTargetTrampolinesKey;

static NSMutableDictionary *swizzledTargetClasses = nil;
static NSMutableDictionary *swizzledObservableClasses = nil;

@implementation NSObject (RACKVOWrapper)

+ (void)load {
	swizzledTargetClasses = [[NSMutableDictionary alloc] init];
	swizzledObservableClasses = [[NSMutableDictionary alloc] init];
}

- (void)rac_customTargetDealloc {
	// If we're currently delivering a KVO callback then niling the trampoline set might not dealloc the trampoline and therefore make them be dealloc'd. So we need to manually stop observing on all of them as well.
	for(RACKVOTrampoline *trampoline in [self.RACKVOTargetTrampolines copy]) {
		[trampoline stopObserving];
	}
	
	objc_setAssociatedObject(self, RACKVOTargetTrampolinesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_customTargetDealloc];
}

- (void)rac_customObservableDealloc {
	// If we're currently delivering a KVO callback then niling the trampoline set might not dealloc the trampoline and therefore make them be dealloc'd. So we need to manually stop observing on all of them as well.
	for(RACKVOTrampoline *trampoline in [self.RACKVOObservingTrampolines copy]) {
		[trampoline stopObserving];
	}
	
	objc_setAssociatedObject(self, RACKVOObservingTrampolinesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_customObservableDealloc];
}

- (id)rac_addObserver:(NSObject *)target forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id target, NSDictionary *change))block {
	// We swizzle the dealloc for both the object being observed and the target of the observation. Because when either gets dealloc'd, we need to tear down the observation.
	@synchronized(swizzledObservableClasses) {
		Class classToSwizzle = [self class];
		NSString *classKey = NSStringFromClass(classToSwizzle);
		if([swizzledObservableClasses objectForKey:classKey] == nil) {
			RACSwizzle(classToSwizzle, NSSelectorFromString(@"dealloc"), @selector(rac_customObservableDealloc));
			[swizzledObservableClasses setObject:[NSNull null] forKey:classKey];
		}
	}
	
	@synchronized(swizzledTargetClasses) {
		Class classToSwizzle = [target class];
		NSString *classKey = NSStringFromClass(classToSwizzle);
		if([swizzledTargetClasses objectForKey:classKey] == nil) {
			RACSwizzle(classToSwizzle, NSSelectorFromString(@"dealloc"), @selector(rac_customTargetDealloc));
			[swizzledTargetClasses setObject:[NSNull null] forKey:classKey];
		}
	}
	
	RACKVOTrampoline *trampoline = [[RACKVOTrampoline alloc] init];
	trampoline.block = block;
	trampoline.keyPath = keyPath;
	trampoline.queue = queue;
	trampoline.target = target;
	[trampoline startObservingObject:self options:options];
	
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

- (NSMutableSet *)RACKVOObservingTrampolines {
    @synchronized(self) {
        NSMutableSet *trampolines = objc_getAssociatedObject(self, RACKVOObservingTrampolinesKey);
        if(trampolines == nil) {
            trampolines = [NSMutableSet set];
            objc_setAssociatedObject(self, RACKVOObservingTrampolinesKey, trampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        return trampolines;
    }
}

- (NSMutableSet *)RACKVOTargetTrampolines {
    @synchronized(self) {
        NSMutableSet *trampolines = objc_getAssociatedObject(self, RACKVOTargetTrampolinesKey);
        if(trampolines == nil) {
            trampolines = [NSMutableSet set];
            objc_setAssociatedObject(self, RACKVOTargetTrampolinesKey, trampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        return trampolines;
    }
}

@end
