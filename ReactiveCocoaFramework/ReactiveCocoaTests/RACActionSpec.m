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
#import "RACSubject.h"
#import "RACUnit.h"

SpecBegin(RACAction)

__block RACAction *action;

__block NSMutableArray *executing;
__block NSMutableArray *enabled;

__block NSUInteger subscriptionCount;
__block NSUInteger disposalCount;

void (^connectAction)(void) = ^{
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
};

RACSignal * (^signalWithValue)(id) = ^(id value) {
	return [[[RACSignal
		defer:^{
			subscriptionCount++;
			return [RACSignal return:value];
		}]
		doDisposed:^{
			disposalCount++;
		}]
		deliverOn:[RACScheduler scheduler]];
};

beforeEach(^{
	subscriptionCount = 0;
	disposalCount = 0;

	executing = [NSMutableArray array];
	enabled = [NSMutableArray array];
});

sharedExamplesFor(@"enabled action", ^(id _) {
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

	it(@"should error if already executing", ^{
		[action execute:nil];

		NSError *error = nil;
		BOOL success = [[action deferred:nil] asynchronouslyWaitUntilCompleted:&error];
		expect(success).to.beFalsy();

		expect(error).notTo.beNil();
		expect(error.domain).to.equal(RACActionErrorDomain);
		expect(error.code).to.equal(RACActionErrorNotEnabled);
		expect(error.userInfo[RACActionErrorKey]).to.beIdenticalTo(action);
	});

	it(@"should send all execution results on the main thread", ^{
		__block BOOL completed = NO;

		[[action deferred:nil] subscribeNext:^(id _) {
			expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
		} completed:^{
			expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
			completed = YES;
		}];

		expect(completed).will.beTruthy();
	});
});

describe(@"from a signal generator", ^{
	__block NSUInteger generationCount;

	beforeEach(^{
		generationCount = 0;

		action = [[RACDynamicSignalGenerator
			generatorWithBlock:^(id value) {
				generationCount++;
				return signalWithValue(value);
			}]
			action];

		expect(action).notTo.beNil();
		connectAction();

		expect(generationCount).to.equal(0);
	});

	itShouldBehaveLike(@"enabled action", @{});

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
});

describe(@"from a signal", ^{
	beforeEach(^{
		action = [signalWithValue(RACUnit.defaultUnit) action];
		expect(action).notTo.beNil();

		connectAction();
	});

	itShouldBehaveLike(@"enabled action", @{});

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
	__block RACSubject *enabledSubject;

	beforeEach(^{
		enabledSubject = [RACSubject subject];

		action = [signalWithValue(nil) actionEnabledIf:enabledSubject];
		expect(action).notTo.beNil();

		connectAction();
	});

	// Before anything is sent upon `enabledSubject`, the action should be
	// enabled.
	itShouldBehaveLike(@"enabled action", @{});

	it(@"should send NO after enabledSignal sends NO", ^{
		[enabledSubject sendNext:@NO];
		expect(enabled).will.equal((@[ @YES, @NO ]));
	});

	it(@"should send NO after enabledSignal sends YES but while executing", ^{
		[enabledSubject sendNext:@YES];

		[action execute:nil];
		expect(executing).will.equal((@[ @NO, @YES, @NO ]));
		expect(enabled).to.equal((@[ @YES, @NO, @YES ]));
	});

	it(@"should send YES after enabledSignal sends YES and not executing", ^{
		[enabledSubject sendNext:@NO];
		expect(enabled).will.equal((@[ @YES, @NO ]));

		[enabledSubject sendNext:@YES];
		expect(enabled).will.equal((@[ @YES, @NO, @YES ]));
	});

	it(@"should immediately sample enabledSignal at initialization time", ^{
		action = [[RACSignal empty] actionEnabledIf:[RACSignal return:@NO]];
		expect([action.enabled first]).to.equal(@NO);
	});

	it(@"should complete upon deallocation even if enabledSignal hasn't", ^{
		__block BOOL deallocated = NO;
		__block BOOL completed = NO;

		@autoreleasepool {
			RACAction *action __attribute__((objc_precise_lifetime)) = [[RACSignal
				empty]
				actionEnabledIf:enabledSubject];

			[action.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			[action.enabled subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(deallocated).will.beTruthy();
		expect(completed).will.beTruthy();
	});
});

it(@"should forward errors on the main thread", ^{
	NSError *testError = [NSError errorWithDomain:@"RACActionSpecDomain" code:321 userInfo:nil];

	action = [[[RACSignal
		error:testError]
		deliverOn:[RACScheduler scheduler]]
		action];
	
	__block NSError *receivedError = nil;
	[action.errors subscribeNext:^(NSError *e) {
		expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);
		receivedError = e;
	}];

	[action execute:nil];
	expect(receivedError).will.equal(testError);
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
