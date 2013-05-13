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
#import "RACUnit.h"
#import <objc/runtime.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;
static const void *RACObjectSelectorInvocationSignals = &RACObjectSelectorInvocationSignals;

@implementation NSObject (RACSelectorSignal)

static RACSignal *NSObjectRACSignalForSelector(id self, SEL _cmd, SEL selector) {
	NSCParameterAssert([NSStringFromSelector(selector) componentsSeparatedByString:@":"].count == 2);

	@synchronized(self) {
		NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorSignals);
		if (selectorSignals == nil) {
			selectorSignals = [NSMutableDictionary dictionary];
			objc_setAssociatedObject(self, RACObjectSelectorSignals, selectorSignals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		NSString *key = NSStringFromSelector(selector);
		RACSubject *subject = selectorSignals[key];
		if (subject != nil) return subject;

		subject = [RACSubject subject];
		IMP imp = imp_implementationWithBlock(^(id self, id arg) {
			[subject sendNext:arg];
		});

		BOOL success = class_addMethod(object_getClass(self), selector, imp, "v@:@");
		NSCAssert(success, @"%@ is already implemented on %@. %@ will not replace the existing implementation.", NSStringFromSelector(selector), self, NSStringFromSelector(_cmd));
		if (!success) return nil;

		selectorSignals[key] = subject;

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

static BOOL NSObjectRACSignalForSelectorWrapImplementation(Method originalMethod, SEL selector, const char *typeEncoding) {
	NSString *key = NSStringFromSelector(selector);
	RACSubject *(^subjectBlock)(id) = ^(id self) {
		@synchronized(self) {
			NSDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorInvocationSignals);
			return selectorSignals[key];
		}
	};

	__block IMP originalImp;
	IMP wrapImp = NULL;

#define WRAP_AND_SEND(type) \
	do { \
		wrapImp = imp_implementationWithBlock(^(id self, type arg) { \
			((void (*)(id, SEL, type))originalImp)(self, selector, arg); \
			RACSubject *subject = subjectBlock(self); \
			[subject sendNext:@(arg)]; \
		}); \
	} while (0)

#define WRAP_AND_SEND_STRUCT(type) \
	do { \
		wrapImp = imp_implementationWithBlock(^(id self, type arg) { \
			((void (*)(id, SEL, type))originalImp)(self, selector, arg); \
			RACSubject *subject = subjectBlock(self); \
			[subject sendNext:[NSValue valueWithBytes:&arg objCType:@encode(type)]]; \
		}); \
	} while (0)

        // Skip const type qualifier.
	if (typeEncoding[0] == 'r') {
		typeEncoding++;
	}

	if (strcmp(typeEncoding, @encode(id)) == 0 || strcmp(typeEncoding, @encode(Class)) == 0) {
		wrapImp = imp_implementationWithBlock(^(id self, id arg) {
			((void (*)(id, SEL, id))originalImp)(self, selector, arg);

			RACSubject *subject = subjectBlock(self);
			[subject sendNext:arg];
		});
	} else if (strcmp(typeEncoding, @encode(char)) == 0) {
		WRAP_AND_SEND(char);
	} else if (strcmp(typeEncoding, @encode(short)) == 0) {
		WRAP_AND_SEND(short);
	} else if (strcmp(typeEncoding, @encode(int)) == 0) {
		WRAP_AND_SEND(int);
	} else if (strcmp(typeEncoding, @encode(long)) == 0) {
		WRAP_AND_SEND(long);
	} else if (strcmp(typeEncoding, @encode(long long)) == 0) {
		WRAP_AND_SEND(long long);
	} else if (strcmp(typeEncoding, @encode(unsigned char)) == 0) {
		WRAP_AND_SEND(unsigned char);
	} else if (strcmp(typeEncoding, @encode(unsigned short)) == 0) {
		WRAP_AND_SEND(unsigned short);
	} else if (strcmp(typeEncoding, @encode(unsigned long)) == 0) {
		WRAP_AND_SEND(unsigned long);
	} else if (strcmp(typeEncoding, @encode(unsigned long long)) == 0) {
		WRAP_AND_SEND(unsigned long long);
	} else if (strcmp(typeEncoding, @encode(float)) == 0) {
		WRAP_AND_SEND(float);
	} else if (strcmp(typeEncoding, @encode(double)) == 0) {
		WRAP_AND_SEND(double);
	} else if (strcmp(typeEncoding, @encode(char *)) == 0) {
		WRAP_AND_SEND(char *);
	} else if (strcmp(typeEncoding, @encode(CGRect)) == 0) {
		WRAP_AND_SEND_STRUCT(CGRect);
	} else if (strcmp(typeEncoding, @encode(CGSize)) == 0) {
		WRAP_AND_SEND_STRUCT(CGSize);
	} else if (strcmp(typeEncoding, @encode(CGPoint)) == 0) {
		WRAP_AND_SEND_STRUCT(CGPoint);
	} else if (strcmp(typeEncoding, @encode(NSRange)) == 0) {
		WRAP_AND_SEND_STRUCT(NSRange);
	} else if (typeEncoding[0] == '^') {
		wrapImp = imp_implementationWithBlock(^(id self, void *arg) {
			((void (*)(id, SEL, void *))originalImp)(self, selector, arg);

			RACSubject *subject = subjectBlock(self);
			[subject sendNext:[NSValue valueWithPointer:arg]];
		});
	} else if (strcmp(typeEncoding, @encode(void)) == 0) {
		wrapImp = imp_implementationWithBlock(^(id self) {
			((void (*)(id, SEL))originalImp)(self, selector);

			RACSubject *subject = subjectBlock(self);
			[subject sendNext:RACUnit.defaultUnit];
		});
	}

	if (wrapImp == NULL) return NO;

	originalImp = method_setImplementation(originalMethod, wrapImp);
	return YES;

#undef WRAP_AND_SEND
#undef WRAP_AND_SEND_STRUCT
}

static BOOL NSObjectRACSignalForSelectorSignalizeImplementation(id self, SEL _cmd, SEL selector, BOOL isClassMethod) {
	static NSMutableSet *replacedClasses;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		replacedClasses = [NSMutableSet set];
	});

	@synchronized(replacedClasses) {
		Class class = object_getClass(self);
		NSString *key = NSStringFromSelector(selector);

		NSString *registKey = [@[NSStringFromClass(class), key] componentsJoinedByString:isClassMethod ? @"+" : @"-"];
		if ([replacedClasses member:registKey]) {
			return YES;
		}

		Method originalMethod = class_getInstanceMethod(class, selector);
		NSCAssert(originalMethod != NULL, @"%@ should already be implemented on %@. %@ could not replace the none existing implementation.", NSStringFromSelector(selector), self, NSStringFromSelector(_cmd));
		if (originalMethod == NULL) return NO;

		NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
		BOOL methodReturnTypeIsVoid = strcmp(methodSignature.methodReturnType, @encode(void)) == 0;
		NSCAssert(methodReturnTypeIsVoid, @"%@ should have void return type on %@.", NSStringFromSelector(selector), self);
		if (!methodReturnTypeIsVoid) return NO;

		const char *typeEncoding = (methodSignature.numberOfArguments == 2) ? @encode(void) : [methodSignature getArgumentTypeAtIndex:2];
		BOOL success = NSObjectRACSignalForSelectorWrapImplementation(originalMethod, selector, typeEncoding);
		NSCAssert(success, @"%@ has unknown argument type %s on %@.", NSStringFromSelector(selector), typeEncoding, self);
		if (!success) return NO;

		[replacedClasses addObject:registKey];
		return YES;
	}
}

static RACSignal *NSObjectRACSignalForSelectorInvocation(id self, SEL _cmd, SEL selector, BOOL isClassMethod) {
	NSCParameterAssert([NSStringFromSelector(selector) componentsSeparatedByString:@":"].count <= 2);

	@synchronized(self) {
		NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorInvocationSignals);
		if (selectorSignals == nil) {
			selectorSignals = [NSMutableDictionary dictionary];
			objc_setAssociatedObject(self, RACObjectSelectorInvocationSignals, selectorSignals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		NSString *key = NSStringFromSelector(selector);
		RACSubject *subject = selectorSignals[key];
		if (subject != nil) return subject;

		BOOL success = NSObjectRACSignalForSelectorSignalizeImplementation(self, _cmd, selector, isClassMethod);
		if (!success) return nil;

		subject = [RACSubject subject];
		selectorSignals[key] = subject;

		[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		return subject;
	}
}

- (RACSignal *)rac_signalForSelectorInvocation:(SEL)selector {
	return NSObjectRACSignalForSelectorInvocation(self, _cmd, selector, NO);
}

+ (RACSignal *)rac_signalForSelectorInvocation:(SEL)selector {
	return NSObjectRACSignalForSelectorInvocation(self, _cmd, selector, YES);
}

@end
