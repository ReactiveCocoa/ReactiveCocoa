//
//  NSObject+RACSelectorSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACSelectorSignal.h"
#import "RACSubject.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "NSInvocation+RACTypeParsing.h"
#import "RACTuple.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;

@implementation NSObject (RACSelectorSignal)

static RACSignal *NSObjectRACSignalForSelector(id self, SEL _cmd, SEL selector) {
	// ???: Should self's class be synchronized?
	@synchronized(self) {
		NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorSignals);
		if (selectorSignals == nil) {
			selectorSignals = [NSMutableDictionary dictionary];
			objc_setAssociatedObject(self, RACObjectSelectorSignals, selectorSignals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		NSString *selectorName = NSStringFromSelector(selector);
		RACSubject *subject = selectorSignals[selectorName];
		if (subject != nil) return subject;

		subject = selectorSignals[selectorName] = [RACSubject subject];

		Class class = object_getClass(self);
		SEL reservedSelector = NSSelectorFromString([@"rac_" stringByAppendingString:selectorName]);
		if ([class instancesRespondToSelector:reservedSelector] && class_getMethodImplementation(class, selector) == _objc_msgForward) {
			return subject;
		}

		Method method = class_getInstanceMethod(class, selector);
		if (method != NULL) {
			// Alias the existing method to reservedSelector.
			class_addMethod(class, reservedSelector, method_getImplementation(method), method_getTypeEncoding(method));
			// Redefine the selector to call -forwardInvocation:
			method_setImplementation(method, _objc_msgForward);
		} else {
			// Define the selector to call -forwardInvocation:
			class_addMethod(class, selector, _objc_msgForward, "v@:@");
		}

		IMP imp = imp_implementationWithBlock(^(id self, NSInvocation *invocation) {
			NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorSignals);
			if (selectorSignals != nil) {
				RACSubject *subject = selectorSignals[selectorName];
				if (subject != nil) {
					RACTuple *argumentsTuple = [RACTuple tupleWithObjectsFromArray:invocation.rac_allArguments];
					[subject sendNext:argumentsTuple];
				}
			}

			// ???: Consider methods that return non-void.
			if ([invocation.target respondsToSelector:reservedSelector]) {
				invocation.selector = reservedSelector;
				[invocation invoke];
			}
		});

		// TODO: Handle case where -forwardInvocation: exists.
		class_replaceMethod(class, @selector(forwardInvocation:), imp, "v@:@");

		[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		return subject;
	}
}

- (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, _cmd, selector);
}

+ (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, _cmd, selector);
}

@end
