//
//  UIAlertViewRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Henrik Hodne on 6/16/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <objc/message.h>
#import "UIAlertView+RACCommandSupport.h"
#import "RACCommand.h"

SpecBegin(UIAlertViewRACSupport)

describe(@"UIAlertView", ^{
	__block UIAlertView *alertView;

	beforeEach(^{
		alertView = [[UIAlertView alloc] initWithFrame:CGRectZero];
		expect(alertView).notTo.beNil();
	});

	it(@"should execute the alert view's command with the index when a button is touched", ^{
		RACCommand *command = [RACCommand command];

		__block BOOL executed = NO;
		__block NSInteger index = -1;
		[command subscribeNext:^(NSNumber *sentIndex) {
			index = sentIndex.integerValue;
			executed = YES;
		}];

		alertView.rac_command = command;

		[alertView.delegate alertView:alertView clickedButtonAtIndex:2];

		expect(executed).to.beTruthy();
		expect(index).to.equal(2);
	});
});

SpecEnd
