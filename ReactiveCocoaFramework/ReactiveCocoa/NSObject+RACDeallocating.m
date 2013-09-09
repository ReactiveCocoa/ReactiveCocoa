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
#import <objc/message.h>
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

		__block void (*originalDealloc)(__unsafe_unretained id, SEL) = NULL;

		id newDealloc = ^(__unsafe_unretained id self) {
			RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
			[compoundDisposable dispose];

			if (originalDealloc == NULL) {
				struct objc_super superInfo = {
					.receiver = self,
					.super_class = class_getSuperclass(classToSwizzle)
				};

				void (*msgSend)(struct objc_super *, SEL) = (__typeof__(msgSend))objc_msgSendSuper;
				msgSend(&superInfo, deallocSelector);
			} else {
				originalDealloc(self, deallocSelector);
			}
		};
		
		IMP newDeallocIMP = imp_implementationWithBlock(newDealloc);
		
		if (!class_addMethod(classToSwizzle, deallocSelector, newDeallocIMP, "v@:")) {
			// The class already contains a method implementation.
			Method deallocMethod = class_getInstanceMethod(classToSwizzle, deallocSelector);
			
			// We need to store original implementation before setting new implementation
			// in case method is called at the time of setting.
			originalDealloc = (__typeof__(originalDealloc))method_getImplementation(deallocMethod);
			
			// We need to store original implementation again, in case it just changed.
			originalDealloc = (__typeof__(originalDealloc))method_setImplementation(deallocMethod, newDeallocIMP);
		}

		[swizzledClasses() addObject:className];
	}
}

@implementation NSObject (RACDeallocating)

- (RACSignal *)rac_willDeallocSignal {
	RACSubject *subject = [RACSubject subject];

	[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		[subject sendCompleted];
	}]];

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

@end

@implementation NSObject (RACDeallocatingDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

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

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	[self.rac_deallocDisposable addDisposable:disposable];
}

#pragma clang diagnostic pop

@end
