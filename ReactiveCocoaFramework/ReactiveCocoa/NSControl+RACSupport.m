//
//  NSControl+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACAction.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACScopedDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import <objc/runtime.h>

static void *NSControlActionKey = &NSControlActionKey;
static void *NSControlActionDisposableKey = &NSControlActionDisposableKey;

@implementation NSControl (RACSupport)

- (void)rac_actionReceived:(id)sender {
	RACSubject *subject = objc_getAssociatedObject(self, @selector(rac_actionSignal));
	[subject sendNext:self];
}

- (RACSignal *)rac_actionSignal {
	@weakify(self);
	return [[[RACSignal
		defer:^{
			@strongify(self);

			RACSubject *subject = objc_getAssociatedObject(self, @selector(rac_actionSignal));
			if (subject == nil) {
				subject = [RACSubject subject];
				objc_setAssociatedObject(self, @selector(rac_actionSignal), subject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

				if (self.target != nil) NSLog(@"WARNING: NSControl.rac_actionSignal hijacks the control's existing target and action");

				self.target = self;
				self.action = @selector(rac_actionReceived:);
			}

			return subject;
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_actionSignal", [self rac_description]];
}

- (RACAction *)rac_action {
	return objc_getAssociatedObject(self, NSControlActionKey);
}

- (void)setRac_action:(RACAction *)action {
	RACAction *previousAction = self.rac_action;
	if (action == previousAction) return;

	objc_setAssociatedObject(self, NSControlActionKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	[objc_getAssociatedObject(self, NSControlActionDisposableKey) dispose];

	if (action == nil) return;

	RACDisposable *enabledDisposable = [action.enabled setKeyPath:@"enabled" onObject:self];
	RACDisposable *actionDisposable = [[self.rac_actionSignal
		doDisposed:^{
			[enabledDisposable dispose];
		}]
		subscribeNext:^(NSControl *control) {
			[action execute:control];
		}];

	objc_setAssociatedObject(self, NSControlActionDisposableKey, actionDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)rac_isEnabled {
	return [self isEnabled];
}

- (void)setRac_enabled:(BOOL)value {
	self.enabled = value;
}

- (RACSignal *)rac_textSignal {
	@weakify(self);
	return [[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSControlTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}]];

			// Start with the current value.
			[subscriber sendNext:self];
		}]
		map:^(NSControl *control) {
			return [control.stringValue copy];
		}]
		setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

static void *NSControlRACCommandKey = &NSControlRACCommandKey;
static void *NSControlEnabledDisposableKey = &NSControlEnabledDisposableKey;

@implementation NSControl (RACSupportDeprecated)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, NSControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, NSControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	// Tear down any previous binding before setting up our new one, or else we
	// might get assertion failures.
	[objc_getAssociatedObject(self, NSControlEnabledDisposableKey) dispose];
	objc_setAssociatedObject(self, NSControlEnabledDisposableKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if (command == nil) {
		self.enabled = YES;
		return;
	}
	
	[self rac_hijackActionAndTargetIfNeeded];

	RACScopedDisposable *disposable = [[command.enabled setKeyPath:@"enabled" onObject:self] asScopedDisposable];
	objc_setAssociatedObject(self, NSControlEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rac_hijackActionAndTargetIfNeeded {
	SEL hijackSelector = @selector(rac_commandPerformAction:);
	if (self.target == self && self.action == hijackSelector) return;
	
	if (self.target != nil) NSLog(@"WARNING: NSControl.rac_command hijacks the control's existing target and action.");
	
	self.target = self;
	self.action = hijackSelector;
}

- (void)rac_commandPerformAction:(id)sender {
	[self.rac_command execute:sender];
}

@end

#pragma clang diagnostic pop
