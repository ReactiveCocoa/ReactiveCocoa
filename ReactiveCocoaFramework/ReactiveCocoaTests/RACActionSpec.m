//
//  RACActionSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-12.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDynamicSignalGenerator.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACUnit.h"

SpecBegin(RACAction)

__block RACAction *action;

__block NSMutableArray *executing;
__block NSMutableArray *enabled;

__block NSUInteger subscriptionCount;
__block NSUInteger disposalCount;

beforeEach(^{
	subscriptionCount = 0;
	disposalCount = 0;

	executing = [NSMutableArray array];
	enabled = [NSMutableArray array];
});

sharedExamplesFor(@"execution", ^(id _) {
	it(@"should be enabled by default", ^{
		expect(enabled).to.equal((@[ @YES ]));
	});

	it(@"should not be executing by default", ^{
		expect(executing).to.equal((@[ @NO ]));
	});

	it(@"should execute asynchronously", ^{
		[action execute:nil];

		expect(subscriptionCount).to.equal(0);
		expect(executing).to.equal((@[ @NO ]));
		expect(enabled).to.equal((@[ @YES ]));

		// Subscription happens asynchronously on the main thread.
		expect(subscriptionCount).will.equal(1);
		expect(executing).will.equal((@[ @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES ]));
		
		expect(disposalCount).to.equal(1);
	});

	it(@"should not send anything on 'errors' by default", ^{
		__block BOOL receivedError = NO;
		[action.errors subscribeNext:^(id _) {
			receivedError = YES;
		}];
		
		expect([[action deferred:nil] asynchronouslyWaitUntilCompleted:NULL]).to.beTruthy();
		expect(receivedError).to.beFalsy();
	});

	pending(@"should error if already executing");
	pending(@"should send all execution results on the main thread");
});

describe(@"from a signal generator", ^{
	__block NSUInteger generationCount;

	beforeEach(^{
		generationCount = 0;

		action = [[RACDynamicSignalGenerator
			generatorWithBlock:^(id value) {
				generationCount++;

				return [[RACSignal
					defer:^{
						subscriptionCount++;
						return [RACSignal return:value];
					}]
					doDisposed:^{
						disposalCount++;
					}];
			}]
			action];

		expect(action).notTo.beNil();
		expect(generationCount).to.equal(0);

		[[action.executing distinctUntilChanged] subscribeNext:^(NSNumber *value) {
			expect(value).to.beKindOf(NSNumber.class);

			if (executing.count > 0) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
			}

			[executing addObject:value];
		}];

		[[action.enabled distinctUntilChanged] subscribeNext:^(NSNumber *value) {
			expect(value).to.beKindOf(NSNumber.class);

			if (enabled.count > 0) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
			}

			[enabled addObject:value];
		}];
	});

	it(@"should generate a new signal with each call to -execute:", ^{
		[action execute:nil];
		expect(generationCount).to.equal(1);
		expect(disposalCount).will.equal(1);

		[action execute:nil];
		expect(generationCount).to.equal(2);
		expect(disposalCount).will.equal(2);
	});

	it(@"should defer execution", ^{
		RACSignal *deferred = [action deferred:RACUnit.defaultUnit];
		expect(deferred).notTo.beNil();

		expect(generationCount).to.equal(1);
		expect(executing).to.equal((@[ @NO ]));
		expect(enabled).to.equal((@[ @YES ]));

		expect([[deferred collect] asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal((@[ RACUnit.defaultUnit ]));
		expect(subscriptionCount).to.equal(1);
		expect(disposalCount).to.equal(1);
		expect(executing).to.equal((@[ @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES ]));

		expect([deferred asynchronouslyWaitUntilCompleted:NULL]).to.beTruthy();
		expect(subscriptionCount).to.equal(2);
		expect(disposalCount).to.equal(2);
		expect(executing).to.equal((@[ @NO, @YES, @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES, @NO, @YES ]));

		// Despite the multiple subscriptions, the underlying signal should've
		// only been generated once.
		expect(generationCount).to.equal(1);
	});

	pending(@"should forward errors on the main thread");
});

describe(@"from a signal", ^{
	beforeEach(^{
		action = [[[RACSignal
			defer:^{
				subscriptionCount++;
				return [RACSignal return:RACUnit.defaultUnit];
			}]
			doDisposed:^{
				disposalCount++;
			}]
			action];

		expect(action).notTo.beNil();

		[[action.executing distinctUntilChanged] subscribeNext:^(NSNumber *value) {
			expect(value).to.beKindOf(NSNumber.class);

			if (executing.count > 0) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
			}

			[executing addObject:value];
		}];

		[[action.enabled distinctUntilChanged] subscribeNext:^(NSNumber *value) {
			expect(value).to.beKindOf(NSNumber.class);

			if (enabled.count > 0) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
			}

			[enabled addObject:value];
		}];
	});

	it(@"should defer execution", ^{
		// The input value should be ignored here.
		RACSignal *deferred = [action deferred:nil];
		expect(deferred).notTo.beNil();

		expect(executing).to.equal((@[ @NO ]));
		expect(enabled).to.equal((@[ @YES ]));

		expect([[deferred collect] asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal((@[ RACUnit.defaultUnit ]));
		expect(subscriptionCount).to.equal(1);
		expect(disposalCount).to.equal(1);
		expect(executing).to.equal((@[ @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES ]));

		expect([deferred asynchronouslyWaitUntilCompleted:NULL]).to.beTruthy();
		expect(subscriptionCount).to.equal(2);
		expect(disposalCount).to.equal(2);
		expect(executing).to.equal((@[ @NO, @YES, @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES, @NO, @YES ]));
	});
});

describe(@"enabled", ^{
	pending(@"should default to YES before enabledSignal sends anything");
	pending(@"should send NO after enabledSignal sends NO");
	pending(@"should send NO after enabledSignal sends YES but while executing");
	pending(@"should send YES after enabledSignal sends YES and not executing");
	pending(@"should immediately sample enabledSignal at initialization time");
	pending(@"should complete upon deallocation even if enabledSignal hasn't");
});

it(@"should complete signals on the main thread when deallocated", ^{
	__block BOOL deallocated = NO;
	__block RACScheduler *executingScheduler = nil;
	__block RACScheduler *enabledScheduler = nil;
	__block RACScheduler *errorsScheduler = nil;

	[[RACScheduler scheduler] schedule:^{
		@autoreleasepool {
			RACAction *action __attribute__((objc_precise_lifetime)) = [[RACSignal
				empty]
				action];

			[action.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			[action.executing subscribeCompleted:^{
				executingScheduler = RACScheduler.currentScheduler;
			}];

			[action.enabled subscribeCompleted:^{
				enabledScheduler = RACScheduler.currentScheduler;
			}];

			[action.errors subscribeCompleted:^{
				errorsScheduler = RACScheduler.currentScheduler;
			}];
		}
	}];

	expect(deallocated).will.beTruthy();
	expect(executingScheduler).will.equal(RACScheduler.mainThreadScheduler);
	expect(enabledScheduler).will.equal(RACScheduler.mainThreadScheduler);
	expect(errorsScheduler).will.equal(RACScheduler.mainThreadScheduler);
});

SpecEnd
