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
#import <objc/runtime.h>

static const void *RACObjectSelectorSignals = &RACObjectSelectorSignals;

@implementation NSObject (RACSelectorSignal)

- (RACSignal *)rac_signalForSelector:(SEL)selector {
	NSParameterAssert([NSStringFromSelector(selector) componentsSeparatedByString:@":"].count == 2);

	@synchronized(self) {
		NSMutableDictionary *selectorSignals = objc_getAssociatedObject(self, RACObjectSelectorSignals);
		if (selectorSignals == nil) {
			selectorSignals = [NSMutableDictionary dictionary];
			objc_setAssociatedObject(self, RACObjectSelectorSignals, selectorSignals, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		NSString *key = [NSString stringWithFormat:@"%@ -> %@", NSStringFromSelector(_cmd), NSStringFromSelector(selector)];
		RACSubject *subject = selectorSignals[key];
		if (subject != nil) return subject;

		subject = [RACSubject subject];
		IMP imp = imp_implementationWithBlock(^(id self, id arg) {
			[subject sendNext:arg];
		});

		BOOL success __attribute__((unused)) = class_addMethod(self.class, selector, imp, "v@:@");
		NSAssert(success, @"%@ is already implemented on %@. %@ will not replace the existing implementation.", NSStringFromSelector(selector), self, NSStringFromSelector(_cmd));

		selectorSignals[key] = subject;

		[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
			[subject sendCompleted];
		}]];

		return subject;
	}
}

@end
