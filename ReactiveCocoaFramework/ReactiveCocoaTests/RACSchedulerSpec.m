//
//  RACSchedulerSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/29/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACDisposable.h"

SpecBegin(RACScheduler)

RACScheduler * (^expectNonNilScheduler)(void (^)(void (^)(void))) = ^(void (^block)(void (^)(void))) {
	__block RACScheduler *currentScheduler;
	block(^{
		currentScheduler = RACScheduler.currentScheduler;
	});

	expect(currentScheduler).willNot.beNil();
	return currentScheduler;
};

it(@"should know its current scheduler", ^{
	void (^expectScheduler)(RACScheduler *, void (^)(void (^)(void))) = ^(RACScheduler *expectedScheduler, void (^block)(void (^)(void))) {
		RACScheduler *currentScheduler = expectNonNilScheduler(block);
		expect(currentScheduler).to.equal(expectedScheduler);
	};

	expectScheduler(RACScheduler.sharedBackgroundScheduler, ^(void (^captureCurrentScheduler)(void)) {
		[RACScheduler.sharedBackgroundScheduler schedule:^{
			[RACScheduler.deferredScheduler schedule:^{
				captureCurrentScheduler();
			}];
		}];
	});

	expectScheduler(RACScheduler.sharedBackgroundScheduler, ^(void (^captureCurrentScheduler)(void)) {
		[RACScheduler.sharedBackgroundScheduler schedule:^{
			[RACScheduler.immediateScheduler schedule:^{
				captureCurrentScheduler();
			}];
		}];
	});

	expectScheduler(RACScheduler.mainQueueScheduler, ^(void (^captureCurrentScheduler)(void)) {
		[RACScheduler.mainQueueScheduler schedule:^{
			[RACScheduler.backgroundScheduler schedule:^{
				[RACScheduler.mainQueueScheduler schedule:^{
					captureCurrentScheduler();
				}];
			}];
		}];
	});

	RACScheduler *backgroundScheduler = RACScheduler.backgroundScheduler;
	expectScheduler(backgroundScheduler, ^(void (^captureCurrentScheduler)(void)) {
		[backgroundScheduler schedule:^{
			[RACScheduler.mainQueueScheduler schedule:^{
				[backgroundScheduler schedule:^{
					captureCurrentScheduler();
				}];
			}];
		}];
	});
});

it(@"shouldn't execute a disposed block", ^{
	__block BOOL executed = NO;
	RACDisposable *disposable = [RACScheduler.deferredScheduler schedule:^{
		executed = YES;
	}];

	expect(executed).to.beFalsy();
	[disposable dispose];
	expect(executed).willNot.beTruthy();
});

describe(@"+deferredScheduler", ^{
	it(@"shouldn't execute the block immediately", ^{
		__block BOOL executed = NO;
		[RACScheduler.deferredScheduler schedule:^{
			executed = YES;
		}];

		expect(executed).to.beFalsy();
		expect(executed).will.beTruthy();
	});
});

describe(@"+subscriptionScheduler", ^{
	it(@"should always have a valid +currentScheduler from within a scheduled block", ^{
		expectNonNilScheduler(^(void (^captureCurrentScheduler)(void)) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[RACScheduler.subscriptionScheduler schedule:^{
					captureCurrentScheduler();
				}];
			});
		});

		expectNonNilScheduler(^(void (^captureCurrentScheduler)(void)) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[RACScheduler.subscriptionScheduler schedule:^{
					captureCurrentScheduler();
				}];
			});
		});
	});

	it(@"should execute scheduled blocks immediately if it's in a scheduler already", ^{
		__block BOOL done = NO;
		[RACScheduler.sharedBackgroundScheduler schedule:^{
			__block BOOL executedImmediately = NO;
			[RACScheduler.subscriptionScheduler schedule:^{
				executedImmediately = YES;
			}];

			expect(executedImmediately).to.beTruthy();
			done = YES;
		}];

		expect(done).will.beTruthy();
	});
});

describe(@"+currentQueueScheduler", ^{
	it(@"should flatten any recursive scheduled blocks", ^{
		NSMutableArray *order = [NSMutableArray array];
		[RACScheduler.currentQueueScheduler schedule:^{
			[order addObject:@1];
			[RACScheduler.currentQueueScheduler schedule:^{
				[order addObject:@3];

				[RACScheduler.currentQueueScheduler schedule:^{
					[order addObject:@5];
				}];

				[order addObject:@4];
			}];
			[order addObject:@2];
		}];

		NSArray *expected = @[ @1, @2, @3, @4, @5 ];
		expect(order).to.equal(expected);
	});
});

describe(@"+immediateScheduler", ^{
	it(@"should immediately execute scheduled blocks", ^{
		__block BOOL executed = NO;
		[RACScheduler.immediateScheduler schedule:^{
			executed = YES;
		}];

		expect(executed).to.beTruthy();
	});
});

SpecEnd
