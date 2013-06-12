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

static void RACSignalForSelectorForwardingIMP(id self, SEL _cmd, NSInvocation *invocation) {
	NSString *selectorName = NSStringFromSelector(invocation.selector);

	NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorSignals);
	if (selectorSignals != nil) {
		RACSubject *subject = selectorSignals[selectorName];
		if (subject != nil) {
			RACTuple *argumentsTuple = [RACTuple tupleWithObjectsFromArray:invocation.rac_allArguments];
			[subject sendNext:argumentsTuple];
		}
	}

	SEL reservedSelector = NSSelectorFromString([@"rac_forward_" stringByAppendingString:selectorName]);
	if ([invocation.target respondsToSelector:reservedSelector]) {
		invocation.selector = reservedSelector;
		[invocation invoke];
	}
}

static RACSignal *NSObjectRACSignalForSelector(id self, SEL selector) {
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
		[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		Class class = object_getClass(self);
		Method method = class_getInstanceMethod(class, selector);

		class_replaceMethod(class, @selector(forwardInvocation:), (IMP)RACSignalForSelectorForwardingIMP, "v@:@");

		if (method_getImplementation(method) == _objc_msgForward) return subject;

		if (method != NULL) {
			// Alias the existing method to reservedSelector.
			SEL reservedSelector = NSSelectorFromString([@"rac_forward_" stringByAppendingString:selectorName]);
			class_addMethod(class, reservedSelector, method_getImplementation(method), method_getTypeEncoding(method));

			// Redefine the selector to call -forwardInvocation:
			method_setImplementation(method, _objc_msgForward);
		} else {
			NSMutableString *signature = [NSMutableString stringWithString:@"v@:"];
			for (NSUInteger i = [selectorName componentsSeparatedByString:@":"].count; i > 1; --i) {
				[signature appendString:@"@"];
			}

			// Define the selector to call -forwardInvocation:
			class_replaceMethod(class, selector, _objc_msgForward, signature.UTF8String);
		}

		return subject;
	}
}

- (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

+ (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

@end
