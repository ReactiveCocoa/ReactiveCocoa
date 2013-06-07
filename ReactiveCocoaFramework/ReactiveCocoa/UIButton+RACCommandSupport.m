//
//  UIButton+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIButton+RACCommandSupport.h"
#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import <ReactiveCocoa/NSObject+RACPropertySubscribing.h>
#import <ReactiveCocoa/RACCommand.h>
#import <ReactiveCocoa/RACDisposable.h>
#import <ReactiveCocoa/RACScheduler.h>
#import <ReactiveCocoa/RACSignal+Operations.h>
#import <ReactiveCocoa/RACSubscriptingAssignmentTrampoline.h>
#import <objc/runtime.h>

static void *UIButtonRACCommandKey = &UIButtonRACCommandKey;
static void *UIButtonCanExecuteDisposableKey = &UIButtonCanExecuteDisposableKey;

@implementation UIButton (RACCommandSupport)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, UIButtonRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, UIButtonRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// Check for stored signal in order to remove it and add a new one
	RACDisposable *disposable = objc_getAssociatedObject(self, UIButtonCanExecuteDisposableKey);
	[disposable dispose];
	
	if (command == nil) return;
	
	disposable = [RACAbleWithStart(command, canExecute) toProperty:@keypath(self.enabled) onObject:self];
	objc_setAssociatedObject(self, UIButtonCanExecuteDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
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
