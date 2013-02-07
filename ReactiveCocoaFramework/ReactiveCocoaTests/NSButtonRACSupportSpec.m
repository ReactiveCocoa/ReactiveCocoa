//
//  NSButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSButton+RACCommandSupport.h"
#import "RACCommand.h"

SpecBegin(NSButtonRACSupport)

it(@"should bind the button's enabledness to the command's canExecute", ^{
	NSButton *button = [[NSButton alloc] initWithFrame:NSZeroRect];
	button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
	expect([button isEnabled]).to.beFalsy();
	
	button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
	expect([button isEnabled]).to.beTruthy();
});

it(@"should execute the button's command when clicked", ^{
	NSButton *button = [[NSButton alloc] initWithFrame:NSZeroRect];
	RACCommand *command = [RACCommand command];

	__block BOOL executed = NO;
	[command subscribeNext:^(id sender) {
		expect(sender).to.equal(button);
		executed = YES;
	}];
	
	button.rac_command = command;
	[button performClick:nil];
	
	expect(executed).to.beTruthy();
});

SpecEnd
