//
//  NSObject+RACDeallocating.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"
#import <objc/runtime.h>

static const void *RACObjectCompoundDisposable = &RACObjectCompoundDisposable;

static NSMutableSet *swizzledClasses() {
	static dispatch_once_t onceToken;
	static NSMutableSet *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableSet alloc] init];
	});
	
	return swizzledClasses;
}

static void swizzleDeallocIfNeeded(Class classToSwizzle) {
	@synchronized (swizzledClasses()) {
		NSString *className = NSStringFromClass(classToSwizzle);
		if ([swizzledClasses() containsObject:className]) return;

		SEL deallocSelector = sel_registerName("dealloc");

		Method deallocMethod = class_getInstanceMethod(classToSwizzle, deallocSelector);
		void (*originalDealloc)(__unsafe_unretained id, SEL) = (__typeof__(originalDealloc))method_getImplementation(deallocMethod);

		id newDealloc = ^(__unsafe_unretained id self) {
			RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
			[compoundDisposable dispose];

			originalDealloc(self, deallocSelector);
		};

		class_replaceMethod(classToSwizzle, deallocSelector, imp_implementationWithBlock(newDealloc), method_getTypeEncoding(deallocMethod));
		[swizzledClasses() addObject:className];
	}
}

@implementation NSObject (RACDeallocating)

- (RACSignal *)rac_willDeallocSignal {
	RACSubject *subject = [RACSubject subject];

	[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[subject sendCompleted];
	}]];

	return subject;
}

- (RACSignal *)rac_didDeallocSignal {
	RACSubject *subject = [RACSubject subject];

	RACScopedDisposable *disposable = [[RACDisposable
		disposableWithBlock:^{
			[subject sendCompleted];
		}]
		asScopedDisposable];
	
	objc_setAssociatedObject(self, (__bridge void *)disposable, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return subject;
}

- (RACCompoundDisposable *)rac_deallocDisposable {
	@synchronized (self) {
		RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
		if (compoundDisposable != nil) return compoundDisposable;

		swizzleDeallocIfNeeded(self.class);

		compoundDisposable = [RACCompoundDisposable compoundDisposable];
		objc_setAssociatedObject(self, RACObjectCompoundDisposable, compoundDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		return compoundDisposable;
	}
}

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	[self.rac_deallocDisposable addDisposable:disposable];
}

@end
