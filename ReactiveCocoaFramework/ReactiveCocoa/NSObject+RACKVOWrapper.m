//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACKVOWrapperPrivate.h"
#import "RACSwizzling.h"
#import "RACKVOTrampoline.h"
#import <objc/runtime.h>

static void *RACKVOTrampolinesKey = &RACKVOTrampolinesKey;

static NSMutableSet *swizzledClasses() {
	static dispatch_once_t onceToken;
	static NSMutableSet *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableSet alloc] init];
	});
	
	return swizzledClasses;
}

@implementation NSObject (RACKVOWrapper)

- (void)rac_customDealloc {
	NSSet *trampolines;
	
	@synchronized (self) {
		trampolines = [self.RACKVOTrampolines copy];
		self.RACKVOTrampolines = nil;
	}

	// If we're currently delivering a KVO callback then niling the trampoline
	// set might not dealloc the trampoline and therefore make them be
	// dealloc'd. So we need to manually stop observing on all of them as well.
	[trampolines makeObjectsPerformSelector:@selector(stopObserving)];

	[self rac_customDealloc];
}

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	void (^swizzle)(Class) = ^(Class classToSwizzle){
		NSString *className = NSStringFromClass(classToSwizzle);
		if ([swizzledClasses() containsObject:className]) return;

		RACSwizzle(classToSwizzle, NSSelectorFromString(@"dealloc"), @selector(rac_customDealloc));
		[swizzledClasses() addObject:className];
	};

	// We swizzle the dealloc for both the object being observed and the
	// observer of the observation. Because when either gets dealloc'd, we need
	// to tear down the observation.
	@synchronized (swizzledClasses()) {
		swizzle(self.class);
		swizzle(observer.class);
	}
	
	return [[RACKVOTrampoline alloc] initWithTarget:self observer:observer keyPath:keyPath options:options block:block];
}

- (void)rac_addKVOTrampoline:(RACKVOTrampoline *)trampoline {
	NSParameterAssert(trampoline != nil);

	@synchronized (self) {
		if (self.RACKVOTrampolines == nil) {
			self.RACKVOTrampolines = [NSMutableArray arrayWithObject:trampoline];
		} else {
			[self.RACKVOTrampolines addObject:trampoline];
		}
	}
}

- (void)rac_removeKVOTrampoline:(RACKVOTrampoline *)trampoline {
	@synchronized (self) {
		[self.RACKVOTrampolines removeObject:trampoline];
	}
}

- (NSMutableArray *)RACKVOTrampolines {
	return objc_getAssociatedObject(self, RACKVOTrampolinesKey);
}

- (void)setRACKVOTrampolines:(NSMutableArray *)set {
	objc_setAssociatedObject(self, RACKVOTrampolinesKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
