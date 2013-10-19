//
//  RACPromiseSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPromise.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import "RACTestScheduler.h"

static NSString * const RACPromiseExamples = @"RACPromiseExamples";
static NSString * const RACPromiseExamplePromiseBlock = @"RACPromiseExamplePromiseBlock";
static NSString * const RACPromiseExampleStartCountBlock = @"RACPromiseExampleStartCountBlock";

SharedExampleGroupsBegin(RACPromiseExamples)

sharedExamplesFor(RACPromiseExamples, ^(NSDictionary *data) {
	__block RACPromise * (^promiseBlock)(RACScheduler *);
	__block NSUInteger (^startCount)(void);

	beforeEach(^{
		promiseBlock = [data[RACPromiseExamplePromiseBlock] copy];
		expect(promiseBlock).notTo.beNil();

		startCount = [data[RACPromiseExampleStartCountBlock] copy];
		expect(startCount).notTo.beNil();
	});

	describe(@"with an immediate scheduler", ^{
		__block RACPromise *promise;

		beforeEach(^{
			promise = promiseBlock(RACScheduler.immediateScheduler);
			expect(promise).notTo.beNil();
			expect(startCount()).to.equal(0);
		});
		
		it(@"should start immediately and deliver results synchronously", ^{
			NSMutableArray *values = [NSMutableArray array];
			__block BOOL completed = NO;

			RACSignal *signal = [promise start];
			expect(signal).notTo.beNil();
			expect(startCount()).to.equal(1);

			[signal subscribeNext:^(id x) {
				[values addObject:x];
			} completed:^{
				completed = YES;
			}];

			expect(completed).to.beTruthy();
			expect(values).to.equal((@[ @1, @2, @3 ]));
		});

		it(@"should deliver results synchronously once automatically started", ^{
			RACSignal *signal = [promise autostart];
			expect(signal).notTo.beNil();
			expect(startCount()).to.equal(0);

			NSMutableArray *values = [NSMutableArray array];
			__block BOOL completed = NO;

			[signal subscribeNext:^(id x) {
				[values addObject:x];
			} completed:^{
				completed = YES;
			}];

			expect(startCount()).to.equal(1);
			expect(completed).to.beTruthy();
			expect(values).to.equal((@[ @1, @2, @3 ]));
		});

		it(@"should only start once", ^{
			NSArray *values = [[promise start] toArray];
			expect(values).to.equal((@[ @1, @2, @3 ]));
			expect(startCount()).to.equal(1);

			expect([[promise start] toArray]).to.equal(values);
			expect(startCount()).to.equal(1);
		});

		it(@"should only autostart once", ^{
			NSArray *values = [[promise autostart] toArray];
			expect(values).to.equal((@[ @1, @2, @3 ]));
			expect(startCount()).to.equal(1);

			expect([[promise autostart] toArray]).to.equal(values);
			expect(startCount()).to.equal(1);
		});
	});

	describe(@"with a test scheduler", ^{
		__block RACPromise *promise;
		__block RACTestScheduler *scheduler;

		__block void (^runOnTestScheduler)(RACSignal * (^)(void));

		beforeEach(^{
			scheduler = [[RACTestScheduler alloc] init];

			promise = promiseBlock(scheduler);
			expect(promise).notTo.beNil();
			expect(startCount()).to.equal(0);

			runOnTestScheduler = ^(RACSignal * (^signalBlock)(void)) {
				NSMutableArray *values = [NSMutableArray array];
				__block BOOL completed = NO;

				[signalBlock() subscribeNext:^(id x) {
					expect(RACScheduler.currentScheduler).to.equal(scheduler);
					[values addObject:x];
				} completed:^{
					expect(RACScheduler.currentScheduler).to.equal(scheduler);
					completed = YES;
				}];

				expect(values).to.equal(@[]);
				expect(completed).to.beFalsy();

				[scheduler stepAll];
				expect(values).to.equal((@[ @1, @2, @3 ]));
				expect(completed).to.beTruthy();
			};
		});
		
		it(@"should start and deliver results on a scheduler", ^{
			runOnTestScheduler(^{
				return [promise start];
			});

			expect(startCount()).to.equal(1);
		});

		it(@"should automatically start and deliver results on a scheduler", ^{
			RACSignal *signal = [promise autostart];
			expect(startCount()).to.equal(0);

			runOnTestScheduler(^{
				return signal;
			});

			expect(startCount()).to.equal(1);

			// This should not start the promise more than once, and values
			// should be delivered on the same scheduler.
			runOnTestScheduler(^{
				return signal;
			});

			expect(startCount()).to.equal(1);
		});

		it(@"should only start once", ^{
			runOnTestScheduler(^{
				return [promise start];
			});

			expect(startCount()).to.equal(1);

			runOnTestScheduler(^{
				return [promise start];
			});

			expect(startCount()).to.equal(1);
		});

		it(@"should only autostart once", ^{
			runOnTestScheduler(^{
				return [promise autostart];
			});

			expect(startCount()).to.equal(1);

			runOnTestScheduler(^{
				return [promise autostart];
			});

			expect(startCount()).to.equal(1);
		});
	});
});

SharedExampleGroupsEnd

SpecBegin(RACPromise)

void (^verifyScheduler)(RACScheduler *) = ^(RACScheduler *scheduler) {
	if (scheduler != RACScheduler.immediateScheduler) {
		expect(RACScheduler.currentScheduler).to.equal(scheduler);
	}
};

describe(@"with a scheduled block", ^{
	itShouldBehaveLike(RACPromiseExamples, ^{
		__block NSUInteger startCount = NO;
		id startCountBlock = ^{
			return startCount;
		};

		id promiseBlock = ^(RACScheduler *scheduler) {
			return [RACPromise promiseWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
				startCount++;
				verifyScheduler(scheduler);

				[subscriber sendNext:@1];
				[subscriber sendNext:@2];
				[subscriber sendNext:@3];
				[subscriber sendCompleted];
			}];
		};

		return @{
			RACPromiseExamplePromiseBlock: promiseBlock,
			RACPromiseExampleStartCountBlock: startCountBlock
		};
	});
});

describe(@"with a signal", ^{
	itShouldBehaveLike(RACPromiseExamples, ^{
		__block NSUInteger startCount = 0;
		id startCountBlock = ^{
			return startCount;
		};

		id promiseBlock = ^(RACScheduler *scheduler) {
			return [[RACSignal
				createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
					startCount++;
					verifyScheduler(scheduler);

					[subscriber sendNext:@1];
					[subscriber sendNext:@2];
					[subscriber sendNext:@3];
					[subscriber sendCompleted];
					return nil;
				}]
				promiseOnScheduler:scheduler];
		};

		return @{
			RACPromiseExamplePromiseBlock: promiseBlock,
			RACPromiseExampleStartCountBlock: startCountBlock
		};
	});
});

SpecEnd
