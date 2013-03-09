//
//  NSControl+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACCommandSupport.h"
#import "RACCommand.h"

#import <objc/runtime.h>

static void * NSControlRACCommandKey = &NSControlRACCommandKey;

@implementation NSControl (RACCommandSupport)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, NSControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, NSControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self unbind:NSEnabledBinding];
	self.enabled = command != nil ? command.canExecute : YES;
	
	if (command == nil) return;
	
	[self bind:NSEnabledBinding toObject:self.rac_command withKeyPath:@"canExecute" options:nil];
	
	[self rac_hijackActionAndTargetIfNeeded];
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
