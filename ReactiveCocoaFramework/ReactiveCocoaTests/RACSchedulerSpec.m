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

	RACScheduler *backgroundScheduler = [RACScheduler scheduler];

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

		expect(secondBlockRan).to.beFalsy();
		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});

	it(@"should schedule future blocks", ^{
		__block BOOL done = NO;

		[RACScheduler.mainThreadScheduler disposableWithDelay:DISPATCH_TIME_NOW andBlock:^{
			done = YES;
		}];

		expect(done).to.beFalsy();
		expect(done).will.beTruthy();
	});

	it(@"should cancel future blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		RACDisposable *disposable = [RACScheduler.mainThreadScheduler disposableWithDelay:DISPATCH_TIME_NOW andBlock:^{
			firstBlockRan = YES;
		}];

		expect(disposable).notTo.beNil();

		[RACScheduler.mainThreadScheduler disposableWithDelay:DISPATCH_TIME_NOW andBlock:^{
			secondBlockRan = YES;
		}];

		[disposable dispose];

		expect(secondBlockRan).to.beFalsy();
		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});
});

describe(@"+scheduler", ^{
	__block RACScheduler *scheduler;
	__block dispatch_time_t (^futureTime)(void);

	beforeEach(^{
		scheduler = [RACScheduler scheduler];

		futureTime = ^{
			return dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC));
		};
	});

	it(@"should cancel scheduled blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

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

	it(@"should schedule future blocks", ^{
		__block BOOL done = NO;

		[scheduler disposableWithDelay:futureTime() andBlock:^{
			done = YES;
		}];

		expect(done).to.beFalsy();
		expect(done).will.beTruthy();
	});

	it(@"should cancel future blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		dispatch_time_t time = futureTime();

		RACDisposable *disposable = [scheduler disposableWithDelay:time andBlock:^{
			firstBlockRan = YES;
		}];

		expect(disposable).notTo.beNil();
		[disposable dispose];

		[scheduler disposableWithDelay:time andBlock:^{
			secondBlockRan = YES;
		}];

		expect(secondBlockRan).to.beFalsy();
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

		it(@"should be a +scheduler when scheduled from an unknown queue", ^{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[RACScheduler.subscriptionScheduler schedule:^{
					currentScheduler = RACScheduler.currentScheduler;
				}];
			});

			expect(currentScheduler).willNot.beNil();
			expect(currentScheduler).notTo.equal(RACScheduler.mainThreadScheduler);
		});

		it(@"should equal the background scheduler from which the block was scheduled", ^{
			RACScheduler *backgroundScheduler = [RACScheduler scheduler];
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

		[[RACScheduler scheduler] schedule:^{
			[RACScheduler.subscriptionScheduler schedule:^{
				executedImmediately = YES;
			}];

			done = YES;
		}];

		expect(done).will.beTruthy();
		expect(executedImmediately).to.beTruthy();
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

	it(@"should block for future scheduled blocks", ^{
		__block BOOL executed = NO;
		RACDisposable *disposable = [RACScheduler.immediateScheduler disposableWithDelay:dispatch_time(DISPATCH_TIME_NOW, 1000) andBlock:^{
			executed = YES;
		}];

		expect(executed).to.beTruthy();
		expect(disposable).to.beNil();
	});
});

describe(@"-scheduleRecursiveBlock:", ^{
	describe(@"with a synchronous scheduler", ^{
		it(@"should behave like a normal block when it doesn't invoke itself", ^{
			__block BOOL executed = NO;
			[RACScheduler.immediateScheduler disposableWithScheduledRecursiveBlock:^(void (^recurse)(void)) {
				expect(executed).to.beFalsy();
				executed = YES;
			}];

			expect(executed).to.beTruthy();
		});

		it(@"should reschedule itself after the caller completes", ^{
			__block NSUInteger count = 0;
			[RACScheduler.immediateScheduler disposableWithScheduledRecursiveBlock:^(void (^recurse)(void)) {
				NSUInteger thisCount = ++count;
				if (thisCount < 3) {
					recurse();

					// The block shouldn't have been invoked again yet, only
					// scheduled.
					expect(count).to.equal(thisCount);
				}
			}];

			expect(count).to.equal(3);
		});
	});

	describe(@"with an asynchronous scheduler", ^{
		it(@"should behave like a normal block when it doesn't invoke itself", ^{
			__block BOOL executed = NO;
			[RACScheduler.mainThreadScheduler disposableWithScheduledRecursiveBlock:^(void (^recurse)(void)) {
				expect(executed).to.beFalsy();
				executed = YES;
			}];

			expect(executed).will.beTruthy();
		});

		it(@"should reschedule itself after the caller completes", ^{
			__block NSUInteger count = 0;
			[RACScheduler.mainThreadScheduler disposableWithScheduledRecursiveBlock:^(void (^recurse)(void)) {
				NSUInteger thisCount = ++count;
				if (thisCount < 3) {
					recurse();

					// The block shouldn't have been invoked again yet, only
					// scheduled.
					expect(count).to.equal(thisCount);
				}
			}];

			expect(count).will.equal(3);
		});

		it(@"shouldn't reschedule itself when disposed", ^{
			__block NSUInteger count = 0;
			__block RACDisposable *disposable = [RACScheduler.mainThreadScheduler disposableWithScheduledRecursiveBlock:^(void (^recurse)(void)) {
				++count;

				expect(disposable).notTo.beNil();
				[disposable dispose];

				recurse();
			}];

			expect(count).will.equal(1);
		});
	});
});

SpecEnd
