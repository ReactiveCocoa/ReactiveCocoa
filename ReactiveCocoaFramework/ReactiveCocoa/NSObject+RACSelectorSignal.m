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
		Class proxySubclass = NULL;
		if (strncmp(class_getName(class), "NSKVONotifying_", 15) == 0) {
			proxySubclass = class;
		} else {
			NSString *subclassSuffix = class_isMetaClass(class) ? @"_RACClassProxy" : @"_RACObjectProxy";
			NSString *proxySubclassName = [[class description] stringByAppendingString:subclassSuffix];
			proxySubclass = NSClassFromString(proxySubclassName);

			if (proxySubclass == nil) {
				proxySubclass = objc_allocateClassPair(class, proxySubclassName.UTF8String, 0);
				objc_registerClassPair(proxySubclass);
			}
		}

		class_replaceMethod(proxySubclass, @selector(forwardInvocation:), (IMP)RACSignalForSelectorForwardingIMP, "v@:@");

		Method method = class_getInstanceMethod(proxySubclass, selector);
		if (method_getImplementation(method) != _objc_msgForward) {
			SEL reservedSelector = NSSelectorFromString([@"rac_forward_" stringByAppendingString:selectorName]);
			if (method != NULL) {
				// Alias the existing method to reservedSelector.
				class_addMethod(proxySubclass, reservedSelector, method_getImplementation(method), method_getTypeEncoding(method));
				// Redefine the selector to call -forwardInvocation:
				method_setImplementation(method, _objc_msgForward);
			} else {
				// Define the selector to call -forwardInvocation:
				NSMutableString *signature = [NSMutableString stringWithString:@"v@:"];
				for (NSUInteger i = [selectorName componentsSeparatedByString:@":"].count; i > 1; --i) {
					[signature appendString:@"@"];
				}
				class_replaceMethod(proxySubclass, selector, _objc_msgForward, signature.UTF8String);
			}
		}

		object_setClass(self, proxySubclass);

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
