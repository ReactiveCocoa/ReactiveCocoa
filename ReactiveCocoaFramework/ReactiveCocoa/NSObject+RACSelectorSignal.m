//
//  NSObject+RACSelectorSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACSelectorSignal.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"
#import "RACTuple.h"
#import <objc/message.h>
#import <objc/runtime.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;
static NSString * const RACSignalForSelectorAliasPrefix = @"rac_alias_";

@implementation NSObject (RACSelectorSignal)

static BOOL RACForwardInvocation(id self, NSInvocation *invocation) {
	SEL aliasSelector = RACAliasForSelector(invocation.selector);

	BOOL (^invokeOriginal)() = ^{
		if (![invocation.target respondsToSelector:aliasSelector]) return NO;

		invocation.selector = aliasSelector;
		[invocation invoke];
		return YES;
	};

	RACSubject *subject = objc_getAssociatedObject(self, aliasSelector);
	if (subject == nil) return invokeOriginal();

	NSArray *arguments = invocation.rac_allArguments;
	invokeOriginal();

	RACTuple *argumentsTuple = [RACTuple tupleWithObjectsFromArray:arguments];
	[subject sendNext:argumentsTuple];
	return YES;
}

static void RACSwizzleForwardInvocation(Class class) {
	SEL forwardInvocationSEL = @selector(forwardInvocation:);
	Method forwardInvocationMethod = class_getInstanceMethod(class, forwardInvocationSEL);

	// Preserve any existing implementation of -forwardInvocation:.
	void (*originalForwardInvocation)(id, SEL, NSInvocation *) = NULL;
	if (forwardInvocationMethod != NULL) {
		originalForwardInvocation = (__typeof__(originalForwardInvocation))method_getImplementation(forwardInvocationMethod);
	}

	// Set up a new version of -forwardInvocation:.
	//
	// If the selector has been passed to -rac_signalForSelector:, invoke
	// the aliased method, and forward the arguments to any attached signals.
	//
	// If the selector has not been passed to -rac_signalForSelector:,
	// invoke any existing implementation of -forwardInvocation:. If there
	// was no existing implementation, throw an unrecognized selector
	// exception.
	id newForwardInvocation = ^(id self, NSInvocation *invocation) {
		BOOL matched = RACForwardInvocation(self, invocation);
		if (matched) return;

		if (originalForwardInvocation == NULL) {
			[self doesNotRecognizeSelector:invocation.selector];
		} else {
			originalForwardInvocation(self, forwardInvocationSEL, invocation);
		}
	};

	class_replaceMethod(class, forwardInvocationSEL, imp_implementationWithBlock(newForwardInvocation), "v@:@");
}

static RACSignal *NSObjectRACSignalForSelector(id self, SEL selector) {
	SEL aliasSelector = RACAliasForSelector(selector);

	@synchronized (self) {
		RACSubject *subject = objc_getAssociatedObject(self, aliasSelector);
		if (subject != nil) return subject;

		subject = [RACSubject subject];
		objc_setAssociatedObject(self, aliasSelector, subject, OBJC_ASSOCIATION_RETAIN);

		[[self rac_deallocDisposable] addDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		Class class = object_getClass(self);
		Method targetMethod = class_getInstanceMethod(class, selector);

		// If this class has previously had -rac_signalForSelector: applied to
		// it, just return the new subject for this instance.
		if (targetMethod != NULL && method_getImplementation(targetMethod) == _objc_msgForward) return subject;

		RACSwizzleForwardInvocation(class);

		if (targetMethod == NULL) {
			// Define the selector to call -forwardInvocation:.
			if (!class_addMethod(class, selector, _objc_msgForward, RACSignatureForUndefinedSelector(selector))) {
				NSLog(@"*** Could not add forwarding for %@ on class %@", NSStringFromSelector(selector), class);
				return nil;
			}
		} else {
			// Make a method alias for the existing method implementation.
			if (!class_addMethod(class, aliasSelector, method_getImplementation(targetMethod), method_getTypeEncoding(targetMethod))) {
				NSLog(@"*** Could not alias %@ to %@ on class %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), class);
				return nil;
			}

			// Redefine the selector to call -forwardInvocation:.
			class_replaceMethod(class, selector, _objc_msgForward, method_getTypeEncoding(targetMethod));
		}

		return subject;
	}
}

static SEL RACAliasForSelector(SEL originalSelector) {
	NSString *selectorName = NSStringFromSelector(originalSelector);
	return NSSelectorFromString([RACSignalForSelectorAliasPrefix stringByAppendingString:selectorName]);
}

static const char *RACSignatureForUndefinedSelector(SEL selector) {
	const char *name = sel_getName(selector);
	NSMutableString *signature = [NSMutableString stringWithString:@"v@:"];

	while ((name = strchr(name, ':')) != NULL) {
		[signature appendString:@"@"];
		name++;
	}

	return signature.UTF8String;
}

- (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

+ (RACSignal *)rac_signalForSelector:(SEL)selector {
	return NSObjectRACSignalForSelector(self, selector);
}

@end
