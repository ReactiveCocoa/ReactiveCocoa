//
//  NSObject+RACSelectorSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACSelectorSignal.h"
#import "NSObject+RACDeallocating.h"
#import "RACDisposable.h"
#import "NSInvocation+RACTypeParsing.h"
#import "RACTuple.h"
#import "RACSubject.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;
static NSString * const RACSignalForSelectorAliasPrefix = @"rac_alias_";

@implementation NSObject (RACSelectorSignal)

static void RACSignalForSelectorForwardingIMP(id self, SEL _cmd, NSInvocation *invocation) {
	RACSubject *subject = RACSubjectForSelector(self, invocation.selector);
	if (subject != nil) {
		RACTuple *argumentsTuple = [RACTuple tupleWithObjectsFromArray:invocation.rac_allArguments];
		[subject sendNext:argumentsTuple];
	}

	SEL reservedSelector = RACAliasForSelector(invocation.selector);
	if ([invocation.target respondsToSelector:reservedSelector]) {
		invocation.selector = reservedSelector;
		[invocation invoke];
	}
}

static RACSignal *NSObjectRACSignalForSelector(id self, SEL selector) {
	@synchronized(self) {
		RACSubject *subject = RACSubjectForSelector(self, selector);
		if (subject != nil) return subject;

		subject = RACCreateSubjectForSignal(self, selector);
		[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		Class class = object_getClass(self);
		Method method = class_getInstanceMethod(class, selector);

		class_replaceMethod(class, @selector(forwardInvocation:), (IMP)RACSignalForSelectorForwardingIMP, "v@:@");

		// If this class has previously had -rac_signalForSelector: applied to
		// it, just return the new subject for this instance.
		if (method_getImplementation(method) == _objc_msgForward) return subject;

		if (method != NULL) {
			// Make a method alias for the existing method implementation.
			class_addMethod(class, RACAliasForSelector(selector), method_getImplementation(method), method_getTypeEncoding(method));

			// Redefine the selector to call -forwardInvocation:
			method_setImplementation(method, _objc_msgForward);
		} else {
			// Define the selector to call -forwardInvocation:
			class_replaceMethod(class, selector, _objc_msgForward, RACSignatureForUndefinedSelector(selector).UTF8String);
		}

		return subject;
	}
}

static RACSubject *RACSubjectForSelector(id object, SEL selector) {
	NSMutableDictionary *selectorSignals = objc_getAssociatedObject(object, RACObjectSelectorSignals);
	if (selectorSignals == nil) return nil;

	return selectorSignals[NSStringFromSelector(selector)];
}

static RACSubject *RACCreateSubjectForSignal(id object, SEL selector) {
	NSMutableDictionary *selectorSignals = objc_getAssociatedObject(object, RACObjectSelectorSignals);
	if (selectorSignals == nil) {
		selectorSignals = [NSMutableDictionary dictionary];
		objc_setAssociatedObject(object, RACObjectSelectorSignals, selectorSignals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return selectorSignals[NSStringFromSelector(selector)] = [RACSubject subject];
}

static SEL RACAliasForSelector(SEL originalSelector) {
	NSString *selectorName = NSStringFromSelector(originalSelector);
	return NSSelectorFromString([RACSignalForSelectorAliasPrefix stringByAppendingString:selectorName]);
}

static NSString *RACSignatureForUndefinedSelector(SEL selector) {
	NSMutableString *signature = [NSMutableString stringWithString:@"v@:"];
	for (NSUInteger i = [NSStringFromSelector(selector) componentsSeparatedByString:@":"].count; i > 1; --i) {
		[signature appendString:@"@"];
	}
	return signature;
}

- (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

+ (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

@end
