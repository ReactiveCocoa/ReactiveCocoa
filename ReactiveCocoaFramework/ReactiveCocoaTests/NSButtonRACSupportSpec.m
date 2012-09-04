//
//  NSButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSButton+RACCommandSupport.h"
#import "RACCommand.h"

SpecBegin(NSButtonRACSupport)

it(@"should bind the button's enabledness to the command's canExecute", ^{
	NSButton *button = [[NSButton alloc] initWithFrame:NSZeroRect];
	button.rac_command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable return:@NO] block:NULL];
	expect([button isEnabled]).to.beFalsy();
	
	button.rac_command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable return:@YES] block:NULL];
	expect([button isEnabled]).to.beTruthy();
});

it(@"should execute the button's command when clicked", ^{
	NSButton *button = [[NSButton alloc] initWithFrame:NSZeroRect];
	
	__block BOOL executed = NO;
	button.rac_command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable return:@YES] block:^(id sender) {
		executed = YES;
	}];
	
	[button performClick:nil];
	
	expect(executed).to.beTruthy();
});

SpecEnd
