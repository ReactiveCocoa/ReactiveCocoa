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
#import <objc/message.h>

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
		__block void (*originalDealloc)(__unsafe_unretained id, SEL) = NULL;

		id newDealloc = ^(__unsafe_unretained id self) {
			RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
			[compoundDisposable dispose];

			if (originalDealloc) {
				// Swizzled method was defined in this class
				originalDealloc(self, deallocSelector);
			}else{
				// Swizzled method was defined in one of the superclasses
				struct objc_super superInfo = {self,class_getSuperclass(classToSwizzle)};
				objc_msgSendSuper(&superInfo, deallocSelector);
			}

		};
		
		// Despite of the fact that we set originalDealloc right in the next line
		// we need originalDealloc not to be NULL for the case of a race condition
		// in which dealloc is called before originalDealloc pointer is actually set.
		originalDealloc = (void *)method_getImplementation(deallocMethod);
		
		// If dealloc method does not yet exist originalDealloc will be NULL
		// and superclasses's implementation will be used.
		originalDealloc = (void *)class_replaceMethod(classToSwizzle, deallocSelector, imp_implementationWithBlock(newDealloc), method_getTypeEncoding(deallocMethod));
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
