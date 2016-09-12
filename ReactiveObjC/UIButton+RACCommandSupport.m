//
//  UIButton+RACCommandSupport.m
//  ReactiveObjC
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIButton+RACCommandSupport.h"
#import <ReactiveObjC/EXTKeyPathCoding.h>
#import "RACCommand.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import <objc/runtime.h>

static void *UIButtonRACCommandKey = &UIButtonRACCommandKey;
static void *UIButtonEnabledDisposableKey = &UIButtonEnabledDisposableKey;

@implementation UIButton (RACCommandSupport)

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
