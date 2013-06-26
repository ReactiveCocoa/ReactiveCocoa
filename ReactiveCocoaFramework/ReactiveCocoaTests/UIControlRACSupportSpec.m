//
//  UIControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestUIButton.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "UIControl+RACSignalSupport.h"

SpecBegin(UIControlRACSupport)

it(@"should send on the returned signal when matching actions are sent", ^{
	UIControl *control = [RACTestUIButton button];
	expect(control).notTo.beNil();

	__block NSUInteger receivedCount = 0;
	[[control
		rac_signalForControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside]
		subscribeNext:^(UIControl *sender) {
			expect(sender).to.beIdenticalTo(control);
			receivedCount++;
		}];

	expect(receivedCount).to.equal(0);
	
	[control sendActionsForControlEvents:UIControlEventTouchUpInside];
	expect(receivedCount).to.equal(1);

	// Should do nothing.
	[control sendActionsForControlEvents:UIControlEventTouchDown];
	expect(receivedCount).to.equal(1);
	
	[control sendActionsForControlEvents:UIControlEventTouchUpOutside];
	expect(receivedCount).to.equal(2);
});

it(@"should send completed when the control is deallocated", ^{
	__block BOOL completed = NO;
	__block BOOL deallocated = NO;

	@autoreleasepool {
		UIControl *control __attribute__((objc_precise_lifetime)) = [RACTestUIButton button];
		[control.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocated = YES;
		}]];

		[[control
			rac_signalForControlEvents:UIControlEventTouchDown]
			subscribeCompleted:^{
				completed = YES;
			}];

		expect(deallocated).to.beFalsy();
		expect(completed).to.beFalsy();
	}

	expect(deallocated).to.beTruthy();
	expect(completed).to.beTruthy();
});

SpecEnd
