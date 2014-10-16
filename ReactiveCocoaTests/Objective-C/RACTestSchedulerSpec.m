//
//  RACTestSchedulerSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestScheduler.h"

QuickSpecBegin(RACTestSchedulerSpec)

__block RACTestScheduler *scheduler;

qck_beforeEach(^{
	scheduler = [[RACTestScheduler alloc] init];
	expect(scheduler).notTo(beNil());
});

qck_it(@"should do nothing when stepping while empty", ^{
	[scheduler step];
	[scheduler step:5];
	[scheduler stepAll];
});

qck_it(@"should execute the earliest enqueued block when stepping", ^{
	__block BOOL firstExecuted = NO;
	[scheduler schedule:^{
		firstExecuted = YES;
	}];

	__block BOOL secondExecuted = NO;
	[scheduler schedule:^{
		secondExecuted = YES;
	}];

	expect(@(firstExecuted)).to(beFalsy());
	expect(@(secondExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(firstExecuted)).to(beTruthy());
	expect(@(secondExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(secondExecuted)).to(beTruthy());
});

qck_it(@"should step multiple times", ^{
	__block BOOL firstExecuted = NO;
	[scheduler schedule:^{
		firstExecuted = YES;
	}];

	__block BOOL secondExecuted = NO;
	[scheduler schedule:^{
		secondExecuted = YES;
	}];

	__block BOOL thirdExecuted = NO;
	[scheduler schedule:^{
		thirdExecuted = YES;
	}];

	expect(@(firstExecuted)).to(beFalsy());
	expect(@(secondExecuted)).to(beFalsy());
	expect(@(thirdExecuted)).to(beFalsy());

	[scheduler step:2];
	expect(@(firstExecuted)).to(beTruthy());
	expect(@(secondExecuted)).to(beTruthy());
	expect(@(thirdExecuted)).to(beFalsy());

	[scheduler step:1];
	expect(@(thirdExecuted)).to(beTruthy());
});

qck_it(@"should step through all scheduled blocks", ^{
	__block NSUInteger executions = 0;
	for (NSUInteger i = 0; i < 10; i++) {
		[scheduler schedule:^{
			executions++;
		}];
	}

	expect(@(executions)).to(equal(@0));

	[scheduler stepAll];
	expect(@(executions)).to(equal(@10));
});

qck_it(@"should execute blocks in date order when stepping", ^{
	__block BOOL laterExecuted = NO;
	[scheduler after:[NSDate distantFuture] schedule:^{
		laterExecuted = YES;
	}];

	__block BOOL earlierExecuted = NO;
	[scheduler after:[NSDate dateWithTimeIntervalSinceNow:20] schedule:^{
		earlierExecuted = YES;
	}];

	expect(@(earlierExecuted)).to(beFalsy());
	expect(@(laterExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(earlierExecuted)).to(beTruthy());
	expect(@(laterExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(laterExecuted)).to(beTruthy());
});

qck_it(@"should execute delayed blocks in date order when stepping", ^{
	__block BOOL laterExecuted = NO;
	[scheduler afterDelay:100 schedule:^{
		laterExecuted = YES;
	}];

	__block BOOL earlierExecuted = NO;
	[scheduler afterDelay:50 schedule:^{
		earlierExecuted = YES;
	}];

	expect(@(earlierExecuted)).to(beFalsy());
	expect(@(laterExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(earlierExecuted)).to(beTruthy());
	expect(@(laterExecuted)).to(beFalsy());

	[scheduler step];
	expect(@(laterExecuted)).to(beTruthy());
});

qck_it(@"should execute a repeating blocks in date order", ^{
	__block NSUInteger firstExecutions = 0;
	[scheduler after:[NSDate dateWithTimeIntervalSinceNow:20] repeatingEvery:5 withLeeway:0 schedule:^{
		firstExecutions++;
	}];

	__block NSUInteger secondExecutions = 0;
	[scheduler after:[NSDate dateWithTimeIntervalSinceNow:22] repeatingEvery:10 withLeeway:0 schedule:^{
		secondExecutions++;
	}];

	expect(@(firstExecutions)).to(equal(@0));
	expect(@(secondExecutions)).to(equal(@0));

	// 20 ticks
	[scheduler step];
	expect(@(firstExecutions)).to(equal(@1));
	expect(@(secondExecutions)).to(equal(@0));

	// 22 ticks
	[scheduler step];
	expect(@(firstExecutions)).to(equal(@1));
	expect(@(secondExecutions)).to(equal(@1));

	// 25 ticks
	[scheduler step];
	expect(@(firstExecutions)).to(equal(@2));
	expect(@(secondExecutions)).to(equal(@1));

	// 30 ticks
	[scheduler step];
	expect(@(firstExecutions)).to(equal(@3));
	expect(@(secondExecutions)).to(equal(@1));

	// 32 ticks
	[scheduler step];
	expect(@(firstExecutions)).to(equal(@3));
	expect(@(secondExecutions)).to(equal(@2));
});

QuickSpecEnd
