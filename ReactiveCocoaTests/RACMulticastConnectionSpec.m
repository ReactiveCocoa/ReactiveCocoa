//
//  RACMulticastConnectionSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACMulticastConnection.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import <libkern/OSAtomic.h>

QuickSpecBegin(RACMulticastConnectionSpec)

__block NSUInteger subscriptionCount = 0;
__block RACMulticastConnection *connection;

qck_beforeEach(^{
	subscriptionCount = 0;
	connection = [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		subscriptionCount++;
		return (RACDisposable *)nil;
	}] publish];

	expect(@(subscriptionCount)).to(equal(@0));
});

qck_describe(@"-connect", ^{
	qck_it(@"should subscribe to the underlying signal", ^{
		[connection connect];
		expect(@(subscriptionCount)).to(equal(@1));
	});

	qck_it(@"should return the same disposable for each invocation", ^{
		RACDisposable *d1 = [connection connect];
		RACDisposable *d2 = [connection connect];
		expect(d1).to(equal(d2));
		expect(@(subscriptionCount)).to(equal(@1));
	});

	qck_it(@"shouldn't reconnect after disposal", ^{
		RACDisposable *disposable1 = [connection connect];
		expect(@(subscriptionCount)).to(equal(@1));

		[disposable1 dispose];
		
		RACDisposable *disposable2 = [connection connect];
		expect(@(subscriptionCount)).to(equal(@1));
		expect(disposable1).to(equal(disposable2));
	});

	qck_it(@"shouldn't race when connecting", ^{
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

		expect([connection connect]).notTo(beNil());
		dispatch_semaphore_signal(semaphore);

		expect(disposable).toEventuallyNot(beNil());
	});
});

qck_describe(@"-autoconnect", ^{
	__block RACSignal *autoconnectedSignal;
	
	qck_beforeEach(^{
		autoconnectedSignal = [connection autoconnect];
	});

	qck_it(@"should subscribe to the multicasted signal on the first subscription", ^{
		expect(@(subscriptionCount)).to(equal(@0));
		
		[autoconnectedSignal subscribeNext:^(id x) {}];
		expect(@(subscriptionCount)).to(equal(@1));

		[autoconnectedSignal subscribeNext:^(id x) {}];
		expect(@(subscriptionCount)).to(equal(@1));
	});

	qck_it(@"should dispose of the multicasted subscription when the signal has no subscribers", ^{
		__block BOOL disposed = NO;
		__block id<RACSubscriber> connectionSubscriber = nil;
		RACSignal *signal = [[[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			// Keep the subscriber alive so it doesn't trigger disposal on dealloc
			connectionSubscriber = subscriber;
			subscriptionCount++;
			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}] publish] autoconnect];
		RACDisposable *disposable = [signal subscribeNext:^(id x) {}];

		expect(@(disposed)).to(beFalsy());
		[disposable dispose];
		expect(@(disposed)).to(beTruthy());
	});

	qck_it(@"shouldn't reconnect after disposal", ^{
		RACDisposable *disposable = [autoconnectedSignal subscribeNext:^(id x) {}];
		expect(@(subscriptionCount)).to(equal(@1));
		[disposable dispose];

		disposable = [autoconnectedSignal subscribeNext:^(id x) {}];
		expect(@(subscriptionCount)).to(equal(@1));
		[disposable dispose];
	});

	qck_it(@"should replay values after disposal when multicasted to a replay subject", ^{
		RACSubject *subject = [RACSubject subject];
		RACSignal *signal = [[subject multicast:[RACReplaySubject subject]] autoconnect];

		NSMutableArray *results1 = [NSMutableArray array];
		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[results1 addObject:x];
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		
		expect(results1).to(equal((@[ @1, @2 ])));
		[disposable dispose];

		NSMutableArray *results2 = [NSMutableArray array];
		[signal subscribeNext:^(id x) {
			[results2 addObject:x];
		}];
		expect(results2).toEventually(equal((@[ @1, @2 ])));
	});
});

QuickSpecEnd
