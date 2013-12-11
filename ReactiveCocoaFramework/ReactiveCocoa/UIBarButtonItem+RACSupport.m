//
//  UIBarButtonItem+RACSupport.m
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 3/27/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIBarButtonItem+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import <objc/runtime.h>

@implementation UIBarButtonItem (RACSupport)

- (void)rac_action:(id)sender {
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

				if (self.target != nil) NSLog(@"WARNING: UIBarButtonItem.rac_actionSignal hijacks the item's existing target and action");

				self.target = self;
				self.action = @selector(rac_action:);
			}

			return subject;
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_actionSignal", [self rac_description]];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

static void *UIControlRACCommandKey = &UIControlRACCommandKey;
static void *UIControlEnabledDisposableKey = &UIControlEnabledDisposableKey;

@implementation UIBarButtonItem (RACSupportDeprecated)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, UIControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, UIControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// Check for stored signal in order to remove it and add a new one
	RACDisposable *disposable = objc_getAssociatedObject(self, UIControlEnabledDisposableKey);
	[disposable dispose];
	
	if (command == nil) return;
	
	disposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];
	objc_setAssociatedObject(self, UIControlEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_hijackActionAndTargetIfNeeded];
}

- (void)rac_hijackActionAndTargetIfNeeded {
	SEL hijackSelector = @selector(rac_commandPerformAction:);
	if (self.target == self && self.action == hijackSelector) return;
	
	if (self.target != nil) NSLog(@"WARNING: UIBarButtonItem.rac_command hijacks the control's existing target and action.");
	
	self.target = self;
	self.action = hijackSelector;
}

- (void)rac_commandPerformAction:(id)sender {
	[self.rac_command execute:sender];
}

@end

#pragma clang diagnostic pop
