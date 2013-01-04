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

	it(@"should replay values after completion when multicasted to a replay subject", ^{
		__block NSUInteger disposeCount = 0;
		RACSignal *s = [[[[RACSignal
			createSignal:^(id<RACSubscriber> subscriber) {
				[subscriber sendNext:@1];
				[subscriber sendNext:@2];
				[subscriber sendCompleted];
				return [RACDisposable disposableWithBlock:^{
					disposeCount++;
				}];
			}]
			collect]
			multicast:[RACReplaySubject subject]]
			autoconnect];

		NSArray *results = [s first];
		expect(disposeCount).to.equal(1);
		expect(results).to.equal((@[ @1, @2 ]));

		results = [s first];
		expect(disposeCount).to.equal(1);
		expect(results).to.equal((@[ @1, @2 ]));
	});
});

SpecEnd
