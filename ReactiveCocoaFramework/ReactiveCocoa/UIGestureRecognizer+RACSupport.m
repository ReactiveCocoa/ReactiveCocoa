//
//  UIGestureRecognizer+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import "UIGestureRecognizer+RACSupport.h"

#import "EXTKeyPathCoding.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACAction.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"

#import <objc/runtime.h>

static void *UIGestureRecognizerActionKey = &UIGestureRecognizerActionKey;
static void *UIGestureRecognizerActionDisposableKey = &UIGestureRecognizerActionDisposableKey;

@implementation UIGestureRecognizer (RACSupport)

- (RACSignal *)rac_gestureSignal {
	@weakify(self);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			[self addTarget:subscriber action:@selector(sendNext:)];
			[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[subscriber sendCompleted];
			}]];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				@strongify(self);
				[self removeTarget:subscriber action:@selector(sendNext:)];
			}]];
		}]
		setNameWithFormat:@"%@ -rac_gestureSignal", [self rac_description]];
}

- (RACAction *)rac_action {
	return objc_getAssociatedObject(self, UIGestureRecognizerActionKey);
}

- (void)setRac_action:(RACAction *)action {
	RACAction *previousAction = self.rac_action;
	if (action == previousAction) return;

	objc_setAssociatedObject(self, UIGestureRecognizerActionKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[objc_getAssociatedObject(self, UIGestureRecognizerActionDisposableKey) dispose];

	if (action == nil) return;

	RACDisposable *enabledDisposable = [action.enabled setKeyPath:@keypath(self.enabled) onObject:self];
	RACDisposable *actionDisposable = [[self.rac_gestureSignal
		doDisposed:^{
			[enabledDisposable dispose];
		}]
		subscribeNext:^(UIGestureRecognizer *recognizer) {
			[action execute:recognizer];
		}];

	objc_setAssociatedObject(self, UIGestureRecognizerActionDisposableKey, actionDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
