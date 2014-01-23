//
//  RACSchedulerSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/29/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACQueueScheduler+Subclass.h"
#import "RACDisposable.h"
#import "EXTScope.h"
#import "RACTestExampleScheduler.h"
#import <libkern/OSAtomic.h>

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

		[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			done = YES;
		}];

		expect(done).to.beFalsy();
		expect(done).will.beTruthy();
	});

	it(@"should cancel future blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		RACDisposable *disposable = [RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			firstBlockRan = YES;
		}];

		expect(disposable).notTo.beNil();

		[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			secondBlockRan = YES;
		}];

		[disposable dispose];

		expect(secondBlockRan).to.beFalsy();
		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});

	it(@"should schedule recurring blocks", ^{
		__block NSUInteger count = 0;

		RACDisposable *disposable = [RACScheduler.mainThreadScheduler after:[NSDate date] repeatingEvery:0.05 withLeeway:0 schedule:^{
			count++;
		}];

		expect(count).to.equal(0);
		expect(count).will.equal(1);
		expect(count).will.equal(2);
		expect(count).will.equal(3);

		[disposable dispose];
		[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

		expect(count).to.equal(3);
	});
});

describe(@"+scheduler", ^{
	__block RACScheduler *scheduler;
	__block NSDate * (^futureDate)(void);

	beforeEach(^{
		scheduler = [RACScheduler scheduler];

		futureDate = ^{
			return [NSDate dateWithTimeIntervalSinceNow:0.01];
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

		[scheduler after:futureDate() schedule:^{
			done = YES;
		}];

		expect(done).to.beFalsy();
		expect(done).will.beTruthy();
	});

	it(@"should cancel future blocks when disposed", ^{
		__block BOOL firstBlockRan = NO;
		__block BOOL secondBlockRan = NO;

		NSDate *date = futureDate();
		RACDisposable *disposable = [scheduler after:date schedule:^{
			firstBlockRan = YES;
		}];

		expect(disposable).notTo.beNil();
		[disposable dispose];

		[scheduler after:date schedule:^{
			secondBlockRan = YES;
		}];

		expect(secondBlockRan).to.beFalsy();
		expect(secondBlockRan).will.beTruthy();
		expect(firstBlockRan).to.beFalsy();
	});

	it(@"should schedule recurring blocks", ^{
		__block NSUInteger count = 0;

		RACDisposable *disposable = [scheduler after:[NSDate date] repeatingEvery:0.05 withLeeway:0 schedule:^{
			count++;
		}];

		expect(count).to.equal(0);
		expect(count).will.equal(1);
		expect(count).will.equal(2);
		expect(count).will.equal(3);

		[disposable dispose];
		[NSThread sleepForTimeInterval:0.1];

		expect(count).to.equal(3);
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
		RACDisposable *disposable = [RACScheduler.immediateScheduler after:[NSDate dateWithTimeIntervalSinceNow:0.01] schedule:^{
			executed = YES;
		}];

		expect(executed).to.beTruthy();
		expect(disposable).to.beNil();
	});
});

describe(@"subclassing", ^{
	__block RACTestExampleScheduler *scheduler;

	beforeEach(^{
		scheduler = [[RACTestExampleScheduler alloc] initWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
	});

	it(@"should invoke blocks scheduled with -schedule:", ^{
		__block BOOL invoked = NO;
		[scheduler schedule:^{
			invoked = YES;
		}];

		expect(invoked).will.beTruthy();
	});

	it(@"should invoke blocks scheduled with -after:schedule:", ^{
		__block BOOL invoked = NO;
		[scheduler after:[NSDate dateWithTimeIntervalSinceNow:0.01] schedule:^{
			invoked = YES;
		}];
		
		expect(invoked).will.beTruthy();
	});

	it(@"should set a valid current scheduler", ^{
		__block RACScheduler *currentScheduler;
		[scheduler schedule:^{
			currentScheduler = RACScheduler.currentScheduler;
		}];

		expect(currentScheduler).will.equal(scheduler);
	});
});

SpecEnd
