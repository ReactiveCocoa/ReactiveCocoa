//
//  RACActionSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"
#import "RACDisposable.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber.h"

SpecBegin(RACAction)

NSError *testError = [NSError errorWithDomain:@"foo" code:100 userInfo:nil];

describe(@"with a synchronous signal", ^{
	__block NSUInteger subscriptionCount;
	__block RACAction *action;

	beforeEach(^{
		subscriptionCount = 0;
		action = [[RACSignal
			createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);

				[subscriber sendNext:@(++subscriptionCount)];
				[subscriber sendCompleted];
				return nil;
			}]
			action];

		expect(action).notTo.beNil();
	});

	it(@"should subscribe on the main thread", ^{
		RACSignal *deferred = [action deferred];
		expect(deferred).notTo.beNil();
		expect(subscriptionCount).to.equal(0);

		__block BOOL success = NO;
		[[RACScheduler scheduler] schedule:^{
			[deferred subscribeCompleted:^{
				success = YES;
			}];
		}];

		expect(success).to.beFalsy();
		expect(success).will.beTruthy();
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should execute asynchronously on the main thread", ^{
		[[RACScheduler scheduler] schedule:^{
			[action execute:nil];
		}];

		expect(subscriptionCount).to.equal(0);
		expect(subscriptionCount).will.equal(1);
	});

	it(@"should execute multiple times", ^{
		RACSignal *deferred = [action deferred];
		expect([deferred asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(@1);
		expect([deferred asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(@2);
		expect([deferred asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(@3);
	});

	it(@"should update executing status", ^{
		NSMutableArray *values = [[NSMutableArray alloc] init];
		[action.executing subscribeNext:^(NSNumber *executing) {
			[values addObject:executing];
		}];

		expect(values).to.equal((@[ @NO ]));
		
		[action execute:nil];
		expect(values).will.equal((@[ @NO, @YES, @NO ]));
	});

	it(@"should immediately send YES on executing while running", ^{
		BOOL success = [[[[action
			deferred]
			initially:^{
				expect([action.executing first]).to.equal(@NO);
			}]
			doNext:^(id _) {
				expect([action.executing first]).to.equal(@YES);
			}]
			asynchronouslyWaitUntilCompleted:NULL];

		expect(success).to.beTruthy();
		expect([action.executing first]).will.equal(@NO);
	});
});

describe(@"with a long-running signal", ^{
	__block NSUInteger subscriptionCount;
	__block NSUInteger disposalCount;

	__block RACSubject *subject;
	__block RACAction *action;

	beforeEach(^{
		subscriptionCount = 0;
		disposalCount = 0;

		subject = [RACSubject subject];
		action = [[RACSignal
			createSignal:^(id<RACSubscriber> subscriber) {
				expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);

				subscriptionCount++;

				RACDisposable *disposable = [subject subscribe:subscriber];
				return [RACDisposable disposableWithBlock:^{
					[disposable dispose];
					disposalCount++;
				}];
			}]
			action];

		expect(action).notTo.beNil();
	});

	it(@"should deliver errors on the main thread", ^{
		[action execute:nil];

		expect(subscriptionCount).will.equal(1);
		expect([action.executing first]).to.equal(@YES);

		__block NSError *receivedError = nil;
		[action.errors subscribeNext:^(NSError *e) {
			expect(RACScheduler.currentScheduler).to.equal(RACScheduler.mainThreadScheduler);

			receivedError = e;
		}];

		[[RACScheduler scheduler] schedule:^{
			[subject sendError:testError];
		}];

		expect(receivedError).will.equal(testError);
		expect([action.executing first]).will.equal(@NO);
	});

	it(@"should deduplicate simultaneous executions", ^{
		RACSignal *deferred = [action deferred];
		expect(deferred).notTo.beNil();

		NSMutableArray *firstValues = [[NSMutableArray alloc] init];
		__block BOOL firstDone = NO;
		[deferred subscribeNext:^(id x) {
			[firstValues addObject:x];
		} completed:^{
			firstDone = YES;
		}];

		expect(subscriptionCount).will.equal(1);
		expect([action.executing first]).to.equal(@YES);
		expect(firstValues).to.equal((@[]));

		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		expect(firstValues).to.equal((@[ @"foo", @"bar" ]));

		NSMutableArray *secondValues = [[NSMutableArray alloc] init];
		__block BOOL secondDone = NO;
		[deferred subscribeNext:^(id x) {
			[secondValues addObject:x];
		} completed:^{
			secondDone = YES;
		}];

		expect(secondValues).to.equal(firstValues);
		expect(subscriptionCount).to.equal(1);
		expect([action.executing first]).to.equal(@YES);

		[subject sendNext:@"buzz"];
		expect(firstValues).to.equal((@[ @"foo", @"bar", @"buzz" ]));
		expect(secondValues).to.equal(firstValues);

		expect(firstDone).to.beFalsy();
		expect(secondDone).to.beFalsy();

		[subject sendCompleted];
		expect(firstDone).to.beTruthy();
		expect(secondDone).to.beTruthy();

		expect([action.executing first]).will.equal(@NO);
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should dispose of the underlying subscription after all deferred subscriptions are disposed", ^{
		RACSignal *deferred = [action deferred];
		expect(deferred).notTo.beNil();

		__block id firstValue;
		RACDisposable *firstDisposable = [deferred subscribeNext:^(id x) {
			firstValue = x;
		}];

		__block id secondValue;
		RACDisposable *secondDisposable = [deferred subscribeNext:^(id x) {
			secondValue = x;
		}];

		expect(firstDisposable).notTo.beNil();
		expect(secondDisposable).notTo.beNil();

		expect(subscriptionCount).will.equal(1);
		expect([action.executing first]).to.equal(@YES);
		expect(disposalCount).to.equal(0);

		[subject sendNext:@"foo"];
		expect(firstValue).to.equal(@"foo");
		expect(secondValue).to.equal(@"foo");

		[firstDisposable dispose];
		expect([action.executing first]).to.equal(@YES);
		expect(disposalCount).to.equal(0);

		[subject sendNext:@"bar"];
		expect(firstValue).to.equal(@"foo");
		expect(secondValue).to.equal(@"bar");

		[secondDisposable dispose];
		expect([action.executing first]).will.equal(@NO);
		expect(disposalCount).to.equal(1);
	});

	it(@"should not dispose of the underlying subscription when -execute: is in progress", ^{
		RACSignal *deferred = [action deferred];
		expect(deferred).notTo.beNil();

		RACDisposable *disposable = [deferred subscribeCompleted:^{}];
		expect(disposable).notTo.beNil();

		[action execute:nil];
		expect(subscriptionCount).will.equal(1);
		expect([action.executing first]).to.equal(@YES);
		expect(disposalCount).to.equal(0);

		[disposable dispose];
		expect([action.executing first]).to.equal(@YES);
		expect(disposalCount).to.equal(0);

		[subject sendCompleted];
		expect([action.executing first]).will.equal(@NO);
	});
});

SpecEnd
