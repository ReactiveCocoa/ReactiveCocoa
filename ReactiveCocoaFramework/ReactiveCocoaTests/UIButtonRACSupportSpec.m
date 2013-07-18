//
//  UIButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestUIButton.h"

#import "UIButton+RACCommandSupport.h"
#import "RACCommand.h"
#import "RACDisposable.h"

SpecBegin(UIButtonRACSupport)

describe(@"UIButton", ^{
	__block UIButton *button;
	
	beforeEach(^{
		button = [RACTestUIButton button];
		expect(button).notTo.beNil();
	});
	
	it(@"should bind the button's enabledness to the command's canExecute", ^{
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		expect(button.enabled).to.beFalsy();
		
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		expect(button.enabled).to.beTruthy();
	});
	
	it(@"should execute the button's command when touched", ^{
		RACCommand *command = [RACCommand command];
		
		__block BOOL executed = NO;
		[command subscribeNext:^(id sender) {
			expect(sender).to.equal(button);
			executed = YES;
		}];
		
		button.rac_command = command;
		
		[button sendActionsForControlEvents:UIControlEventTouchUpInside];
		
		expect(executed).to.beTruthy();
	});
});

SpecEnd
