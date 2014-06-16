//
//  UIButton+RACSupport.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIButton+RACSupport.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACAction.h"
#import "RACCommand.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "UIControl+RACSupport.h"

#import <objc/runtime.h>

static void *UIButtonActionKey = &UIButtonActionKey;
static void *UIButtonActionDisposableKey = &UIButtonActionDisposableKey;

@implementation UIButton (RACSupport)

- (RACAction *)rac_action {
	return objc_getAssociatedObject(self, UIButtonActionKey);
}

- (void)setRac_action:(RACAction *)action {
	RACAction *previousAction = self.rac_action;
	if (action == previousAction) return;

	objc_setAssociatedObject(self, UIButtonActionKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[objc_getAssociatedObject(self, UIButtonActionDisposableKey) dispose];

	if (action == nil) return;

	RACDisposable *enabledDisposable = [action.enabled setKeyPath:@keypath(self.enabled) onObject:self];
	RACDisposable *actionDisposable = [[[self
		rac_signalForControlEvents:UIControlEventTouchUpInside]
		doDisposed:^{
			[enabledDisposable dispose];
		}]
		subscribeNext:^(UIButton *control) {
			[action execute:control];
		}];

	objc_setAssociatedObject(self, UIButtonActionDisposableKey, actionDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

static void *UIButtonRACCommandKey = &UIButtonRACCommandKey;
static void *UIButtonEnabledDisposableKey = &UIButtonEnabledDisposableKey;

@implementation UIButton (RACSupportDeprecated)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, UIButtonRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, UIButtonRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// Check for stored signal in order to remove it and add a new one
	RACDisposable *disposable = objc_getAssociatedObject(self, UIButtonEnabledDisposableKey);
	[disposable dispose];
	
	if (command == nil) return;
	
	disposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];
	objc_setAssociatedObject(self, UIButtonEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_hijackActionAndTargetIfNeeded];
}

- (void)rac_hijackActionAndTargetIfNeeded {
	SEL hijackSelector = @selector(rac_commandPerformAction:);
	
	for (NSString *selector in [self actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]) {
		if (hijackSelector == NSSelectorFromString(selector)) {
			return;
		}
	}
	
	[self addTarget:self action:hijackSelector forControlEvents:UIControlEventTouchUpInside];
}

- (void)rac_commandPerformAction:(id)sender {
	[self.rac_command execute:sender];
}

@end

#pragma clang diagnostic pop
