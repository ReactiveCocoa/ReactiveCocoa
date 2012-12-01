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

	expectCurrentSchedulers(@[ backgroundScheduler, RACScheduler.deferredScheduler ], @[ backgroundScheduler, backgroundScheduler ]);
	expectCurrentSchedulers(@[ backgroundScheduler, RACScheduler.immediateScheduler ], @[ backgroundScheduler, backgroundScheduler ]);
	expectCurrentSchedulers(@[ backgroundScheduler, RACScheduler.subscriptionScheduler ], @[ backgroundScheduler, backgroundScheduler ]);

	NSArray *mainThreadJumper = @[ RACScheduler.mainThreadScheduler, backgroundScheduler, RACScheduler.mainThreadScheduler ];
	expectCurrentSchedulers(mainThreadJumper, mainThreadJumper);

	NSArray *backgroundJumper = @[ backgroundScheduler, RACScheduler.mainThreadScheduler, backgroundScheduler ];
	expectCurrentSchedulers(backgroundJumper, backgroundJumper);
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
		__block RACScheduler *currentScheduler;
		dispatch_async(dispatch_get_main_queue(), ^{
			[RACScheduler.subscriptionScheduler schedule:^{
				currentScheduler = RACScheduler.currentScheduler;
			}];
		});
		expect(currentScheduler).will.equal(RACScheduler.mainThreadScheduler);

		currentScheduler = nil;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[RACScheduler.subscriptionScheduler schedule:^{
				currentScheduler = RACScheduler.currentScheduler;
			}];
		});
		expect(currentScheduler).will.equal(RACScheduler.mainThreadScheduler);

		currentScheduler = nil;
		RACScheduler *backgroundScheduler = RACScheduler.backgroundScheduler;
		[backgroundScheduler schedule:^{
			[RACScheduler.subscriptionScheduler schedule:^{
				currentScheduler = RACScheduler.currentScheduler;
			}];
		}];
		expect(currentScheduler).will.equal(backgroundScheduler);
	});

	it(@"should execute scheduled blocks immediately if it's in a scheduler already", ^{
		__block BOOL done = NO;
		[RACScheduler.backgroundScheduler schedule:^{
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

describe(@"+iterativeScheduler", ^{
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
