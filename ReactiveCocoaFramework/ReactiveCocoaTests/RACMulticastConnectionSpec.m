//
//  RACMulticastConnectionSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACMulticastConnection.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import <libkern/OSAtomic.h>

SpecBegin(RACMulticastConnection)

__block NSUInteger subscriptionCount = 0;
__block RACMulticastConnection *connection;
__block BOOL disposed = NO;

beforeEach(^{
	subscriptionCount = 0;
	disposed = NO;
	connection = [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		subscriptionCount++;
		return [RACDisposable disposableWithBlock:^{
			disposed = YES;
		}];
	}] publish];
	expect(subscriptionCount).to.equal(0);
});

describe(@"-connect", ^{
	it(@"should subscribe to the underlying signal", ^{
		[connection connect];
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should return the same disposable for each invocation", ^{
		RACDisposable *d1 = [connection connect];
		RACDisposable *d2 = [connection connect];
		expect(d1).to.equal(d2);
		expect(subscriptionCount).to.equal(1);
	});

	it(@"shouldn't reconnect after disposal", ^{
		RACDisposable *disposable1 = [connection connect];
		expect(subscriptionCount).to.equal(1);

		[disposable1 dispose];
		
		RACDisposable *disposable2 = [connection connect];
		expect(subscriptionCount).to.equal(1);
		expect(disposable1).to.equal(disposable2);
	});

	it(@"shouldn't race when connecting", ^{
		dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

		RACMulticastConnection *connection = [[RACSignal
			defer:^ id {
				dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
				return nil;
			}]
			publish];

		__block RACDisposable *disposable;
		[RACScheduler.scheduler schedule:^{
			disposable = [connection connect];
			dispatch_semaphore_signal(semaphore);
		}];

		expect([connection connect]).notTo.beNil();
		dispatch_semaphore_signal(semaphore);

		expect(disposable).willNot.beNil();

		dispatch_release(semaphore);
	});
});

describe(@"-autoconnect", ^{
	__block RACSignal *autoconnectedSignal;
	
	beforeEach(^{
		autoconnectedSignal = [connection autoconnect];
	});

	it(@"should subscribe to the multicasted signal on the first subscription", ^{
		expect(subscriptionCount).to.equal(0);
		
		[autoconnectedSignal subscribeNext:^(id x) {}];
		expect(subscriptionCount).to.equal(1);

		[autoconnectedSignal subscribeNext:^(id x) {}];
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should dispose of the multicasted subscription when the signal has no subscribers", ^{
		RACDisposable *disposable = [autoconnectedSignal subscribeNext:^(id x) {}];

		expect(disposed).to.beFalsy();
		[disposable dispose];
		expect(disposed).to.beTruthy();
	});

	it(@"shouldn't reconnect after disposal", ^{
		RACDisposable *disposable = [autoconnectedSignal subscribeNext:^(id x) {}];
		expect(subscriptionCount).to.equal(1);
		[disposable dispose];

		disposable = [autoconnectedSignal subscribeNext:^(id x) {}];
		expect(subscriptionCount).to.equal(1);
		[disposable dispose];
	});

	it(@"should replay values after disposal when multicasted to a replay subject", ^{
		RACSubject *subject = [RACSubject subject];
		RACSignal *signal = [[subject multicast:[RACReplaySubject subject]] autoconnect];

		NSMutableArray *results1 = [NSMutableArray array];
		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[results1 addObject:x];
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		
		expect(results1).to.equal((@[ @1, @2 ]));
		[disposable dispose];

		NSMutableArray *results2 = [NSMutableArray array];
		[signal subscribeNext:^(id x) {
			[results2 addObject:x];
		}];
		expect(results2).will.equal((@[ @1, @2 ]));
	});
});

SpecEnd
