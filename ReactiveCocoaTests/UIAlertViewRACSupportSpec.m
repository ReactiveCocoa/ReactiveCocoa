//
//  UIAlertViewRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Henrik Hodne on 6/16/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import <objc/message.h>
#import "RACSignal.h"
#import "UIAlertView+RACSignalSupport.h"

QuickSpecBegin(UIAlertViewRACSupportSpec)

qck_describe(@"UIAlertView", ^{
	__block UIAlertView *alertView;

	qck_beforeEach(^{
		alertView = [[UIAlertView alloc] initWithFrame:CGRectZero];
		expect(alertView).notTo(beNil());
	});

	qck_it(@"sends the index of the clicked button to the buttonClickedSignal when a button is clicked", ^{
		__block NSInteger index = -1;
		[alertView.rac_buttonClickedSignal subscribeNext:^(NSNumber *sentIndex) {
			index = sentIndex.integerValue;
		}];

		[alertView.delegate alertView:alertView clickedButtonAtIndex:2];
		expect(@(index)).to(equal(@2));
	});

	qck_it(@"sends the index of the appropriate button to the willDismissSignal when dismissed programatically", ^{
		__block NSInteger index = -1;
		[alertView.rac_willDismissSignal subscribeNext:^(NSNumber *sentIndex) {
			index = sentIndex.integerValue;
		}];

		[alertView.delegate alertView:alertView willDismissWithButtonIndex:2];
		expect(@(index)).to(equal(@2));
	});
});

QuickSpecEnd
