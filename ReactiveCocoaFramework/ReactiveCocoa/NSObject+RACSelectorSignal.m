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
#import "RACSubject.h"
#import <objc/runtime.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;

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

@end
