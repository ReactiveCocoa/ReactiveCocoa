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

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	void (^swizzle)(Class) = ^(Class classToSwizzle){
		NSString *className = NSStringFromClass(classToSwizzle);
		NSCAssert(![classToSwizzle isEqual:NSObject.class], @"NSObject's dealloc must not be swizzled.");
		if (className == nil) return;
		if ([swizzledClasses() containsObject:className]) return;

		SEL deallocSelector = sel_registerName("dealloc");

		Method deallocMethod = class_getInstanceMethod(classToSwizzle, deallocSelector);
		void (*originalDealloc)(id, SEL) = (__typeof__(originalDealloc))method_getImplementation(deallocMethod);

		id newDealloc = ^(__unsafe_unretained NSObject *self) {
			NSArray *trampolines;

			@synchronized (self) {
				trampolines = objc_getAssociatedObject(self, RACKVOTrampolinesKey);
				objc_setAssociatedObject(self, RACKVOTrampolinesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}

			// If we're currently delivering a KVO callback then niling
			// the trampoline set might not dealloc the trampoline and
			// therefore make them be dealloc'd. So we need to manually
			// stop observing on all of them as well.
			[trampolines makeObjectsPerformSelector:@selector(stopObserving)];

			originalDealloc(self, deallocSelector);
		};

		class_replaceMethod(classToSwizzle, deallocSelector, imp_implementationWithBlock(newDealloc), method_getTypeEncoding(deallocMethod));

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
	NSCParameterAssert(trampoline != nil);

	@synchronized (self) {
		NSMutableArray *trampolines = objc_getAssociatedObject(self, RACKVOTrampolinesKey);
		if (trampolines == nil) {
			trampolines = [[NSMutableArray alloc] init];
			objc_setAssociatedObject(self, RACKVOTrampolinesKey, trampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		[trampolines addObject:trampoline];
	}
}

- (void)rac_removeKVOTrampoline:(RACKVOTrampoline *)trampoline {
	@synchronized (self) {
		NSMutableArray *trampolines = objc_getAssociatedObject(self, RACKVOTrampolinesKey);
		[trampolines removeObjectIdenticalTo:trampoline];
	}
}

@end
