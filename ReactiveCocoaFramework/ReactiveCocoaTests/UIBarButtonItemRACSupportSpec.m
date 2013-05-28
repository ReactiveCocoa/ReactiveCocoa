//
//  UIBarButtonItemRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 4/13/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <objc/message.h>
#import "UIBarButtonItem+RACCommandSupport.h"
#import "RACCommand.h"
#import "RACDisposable.h"

SpecBegin(UIBarButtonItemRACSupport)

describe(@"UIBarButtonItem", ^{
	__block UIBarButtonItem *button;
	
	beforeEach(^{
		button = [[UIBarButtonItem alloc] init];
		expect(button).notTo.beNil();
	});
		
	it(@"should bind the button's enabledness to the command's canExecute", ^{
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		expect([button isEnabled]).to.beFalsy();
		
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		expect([button isEnabled]).to.beTruthy();
	});
	
	it(@"should overwrite existing an signal when re-assign the command", ^{
		RACCommand *cmd1 = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		button.rac_command = cmd1;
		expect(button.rac_command).to.equal(cmd1);
		
		RACCommand *cmd2 = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		button.rac_command = cmd2;
		expect(button.rac_command).toNot.equal(cmd1);
		expect(button.rac_command).to.equal(cmd2);
	});
	
	it(@"should execute the button's command when touched", ^{
		RACCommand *command = [RACCommand command];
		
		__block BOOL executed = NO;
		[command subscribeNext:^(id sender) {
			expect(sender).to.equal(button);
			executed = YES;
		}];
		
		button.rac_command = command;
		
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[button.target performSelector:button.action withObject:button.target];
#pragma clang diagnostic pop
		
		expect(executed).to.beTruthy();
	});
});

SpecEnd
