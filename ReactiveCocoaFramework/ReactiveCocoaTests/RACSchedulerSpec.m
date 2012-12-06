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
#import "EXTScope.h"

// This shouldn't be used directly. Use the `expectCurrentSchedulers` block
// below instead.
static void expectCurrentSchedulersInner(NSArray *schedulers, NSMutableArray *currentSchedulerArray) {
	if (schedulers.count > 0) {
		RACScheduler *topScheduler = schedulers[0];
		[topScheduler schedule:^{
			RACScheduler *currentScheduler = RACScheduler.currentScheduler;
			if (currentScheduler != nil) [currentSchedulerArray addObject:currentScheduler];
			expectCurrentSchedulersInner([schedulers subarrayWithRange:NSMakeRange(1, schedulers.count - 1)], currentSchedulerArray);
		}];
	}
}

SpecBegin(RACScheduler)

it(@"should know its current scheduler", ^{
	// Recursively schedules a block in each of the given schedulers and records
	// the +currentScheduler at each step. It then expects the array of
	// +currentSchedulers and the expected array to be equal.
	//
	// schedulers                - The array of schedulers to recursively schedule.
	// expectedCurrentSchedulers - The array of +currentSchedulers to expect.
	void (^expectCurrentSchedulers)(NSArray *, NSArray *) = ^(NSArray *schedulers, NSArray *expectedCurrentSchedulers) {
		NSMutableArray *currentSchedulerArray = [NSMutableArray array];
		expectCurrentSchedulersInner(schedulers, currentSchedulerArray);
		expect(currentSchedulerArray).will.equal(expectedCurrentSchedulers);
	};

	RACScheduler *backgroundScheduler = RACScheduler.backgroundScheduler;

	expectCurrentSchedulers(@[ backgroundScheduler, RACScheduler.immediateScheduler ], @[ backgroundScheduler, backgroundScheduler ]);
	expectCurrentSchedulers(@[ backgroundScheduler, RACScheduler.subscriptionScheduler ], @[ backgroundScheduler, backgroundScheduler ]);

	NSArray *mainThreadJumper = @[ RACScheduler.mainThreadScheduler, backgroundScheduler, RACScheduler.mainThreadScheduler ];
	expectCurrentSchedulers(mainThreadJumper, mainThreadJumper);

	NSArray *backgroundJumper = @[ backgroundScheduler, RACScheduler.mainThreadScheduler, backgroundScheduler ];
	expectCurrentSchedulers(backgroundJumper, backgroundJumper);
});

describe(@"+mainThreadScheduler", ^{
	it(@"should cancel scheduled blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		RACDisposable *disposable = [RACScheduler.mainThreadScheduler schedule:^{
			firstBlockRan = YES;
		}];

		expect(disposable).notTo.beNil();

		[RACScheduler.mainThreadScheduler schedule:^{
			secondBlockRan = YES;
		}];

		[disposable dispose];

		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});
});

describe(@"+backgroundScheduler", ^{
	it(@"should cancel scheduled blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		RACScheduler *scheduler = [RACScheduler backgroundScheduler];

		// Start off on the scheduler so the enqueued blocks won't run until we
		// return.
		[scheduler schedule:^{
			RACDisposable *disposable = [scheduler schedule:^{
				firstBlockRan = YES;
			}];

			expect(disposable).notTo.beNil();

			[scheduler schedule:^{
				secondBlockRan = YES;
			}];

			[disposable dispose];
		}];

		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});
});

describe(@"+subscriptionScheduler", ^{
	describe(@"setting +currentScheduler", ^{
		__block RACScheduler *currentScheduler;

		beforeEach(^{
			currentScheduler = nil;
		});

		it(@"should be the +mainThreadScheduler when scheduled from the main queue", ^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[RACScheduler.subscriptionScheduler schedule:^{
					currentScheduler = RACScheduler.currentScheduler;
				}];
			});

			expect(currentScheduler).will.equal(RACScheduler.mainThreadScheduler);
		});

		it(@"should be the +mainThreadScheduler when scheduled from an unknown queue", ^{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[RACScheduler.subscriptionScheduler schedule:^{
					currentScheduler = RACScheduler.currentScheduler;
				}];
			});

			expect(currentScheduler).will.equal(RACScheduler.mainThreadScheduler);
		});

		it(@"should equal the background scheduler from which the block was scheduled", ^{
			RACScheduler *backgroundScheduler = RACScheduler.backgroundScheduler;
			[backgroundScheduler schedule:^{
				[RACScheduler.subscriptionScheduler schedule:^{
					currentScheduler = RACScheduler.currentScheduler;
				}];
			}];

			expect(currentScheduler).will.equal(backgroundScheduler);
		});
	});

	it(@"should execute scheduled blocks immediately if it's in a scheduler already", ^{
		__block BOOL done = NO;
		__block BOOL executedImmediately = NO;

		[RACScheduler.backgroundScheduler schedule:^{
			[RACScheduler.subscriptionScheduler schedule:^{
				executedImmediately = YES;
			}];

			done = YES;
		}];

		expect(done).will.beTruthy();
		expect(executedImmediately).to.beTruthy();
	});

	it(@"should cancel scheduled blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		dispatch_group_t group = dispatch_group_create();
		@onExit {
			dispatch_release(group);
		};

		// Schedule from a background thread so that it enqueues on the main
		// thread.
		dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			RACDisposable *disposable = [RACScheduler.subscriptionScheduler schedule:^{
				firstBlockRan = YES;
			}];

			expect(disposable).notTo.beNil();

			[RACScheduler.subscriptionScheduler schedule:^{
				secondBlockRan = YES;
			}];

			[disposable dispose];
		});

		// Block waiting for scheduling to complete.
		dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});
});

describe(@"+iterativeScheduler", ^{
	it(@"should run immediately on the main scheduler", ^{
		__block RACScheduler *scheduler = nil;

		[RACScheduler.iterativeScheduler schedule:^{
			scheduler = RACScheduler.currentScheduler;
		}];

		expect(scheduler).to.equal(RACScheduler.mainThreadScheduler);
	});

	it(@"should run immediately on a background scheduler", ^{
		__block BOOL done = NO;
		__block RACScheduler *scheduler = nil;

		RACScheduler *backgroundScheduler = RACScheduler.backgroundScheduler;
		[backgroundScheduler schedule:^{
			[RACScheduler.iterativeScheduler schedule:^{
				scheduler = RACScheduler.currentScheduler;
			}];

			done = YES;
		}];

		expect(done).will.beTruthy();
		expect(scheduler).to.equal(backgroundScheduler);
	});

	it(@"should run on the main scheduler when invoked from an unknown scheduler", ^{
		__block BOOL done = NO;
		__block RACScheduler *scheduler = nil;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[RACScheduler.iterativeScheduler schedule:^{
				scheduler = RACScheduler.currentScheduler;
			}];

			done = YES;
		});

		expect(done).will.beTruthy();
		expect(scheduler).to.equal(RACScheduler.mainThreadScheduler);
	});

	it(@"should flatten any recursive scheduled blocks", ^{
		NSMutableArray *order = [NSMutableArray array];
		[RACScheduler.iterativeScheduler schedule:^{
			[order addObject:@1];

			[RACScheduler.iterativeScheduler schedule:^{
				[order addObject:@3];

				[RACScheduler.iterativeScheduler schedule:^{
					[order addObject:@5];
				}];

				[order addObject:@4];
			}];

			[order addObject:@2];
		}];

		NSArray *expected = @[ @1, @2, @3, @4, @5 ];
		expect(order).will.equal(expected);
	});

	it(@"should cancel scheduled blocks when disposed", ^{
		NSMutableArray *order = [NSMutableArray array];
		[RACScheduler.iterativeScheduler schedule:^{
			[order addObject:@1];

			RACDisposable *disposable = [RACScheduler.iterativeScheduler schedule:^{
				[order addObject:@3];
			}];

			expect(disposable).notTo.beNil();
			[disposable dispose];

			[order addObject:@2];
		}];

		NSArray *expected = @[ @1, @2 ];
		expect(order).will.equal(expected);
	});
});

describe(@"+immediateScheduler", ^{
	it(@"should immediately execute scheduled blocks", ^{
		__block BOOL executed = NO;
		RACDisposable *disposable = [RACScheduler.immediateScheduler schedule:^{
			executed = YES;
		}];

		expect(disposable).to.beNil();
		expect(executed).to.beTruthy();
	});
});

SpecEnd
