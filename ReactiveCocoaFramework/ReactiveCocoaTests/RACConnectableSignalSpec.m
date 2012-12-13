//
//  RACConnectableSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSignal.h"
#import "RACDisposable.h"
#import "RACSubscriber.h"

SpecBegin(RACConnectableSignal)

describe(@"-autoconnect", ^{
	__block BOOL disposed = NO;
	__block NSUInteger numberOfSubscriptions = 0;
	__block id<RACSignal> signal;

	beforeEach(^{
		disposed = NO;
		numberOfSubscriptions = 0;
		signal = [[[RACConnectableSignal
			createSignal:^(id<RACSubscriber> subscriber) {
				numberOfSubscriptions++;

				return [RACDisposable disposableWithBlock:^{
					numberOfSubscriptions--;
					disposed = YES;
				}];
			}]
		publish]
		autoconnect];
	});

	it(@"should connect to the underlying signal on the first subscription", ^{
		[signal subscribeNext:^(id _) {}];

		expect(numberOfSubscriptions).to.equal(1);
	});

	it(@"shouldn't reconnect for more subscriptions", ^{
		[signal subscribeNext:^(id _) {}];
		[signal subscribeNext:^(id _) {}];

		expect(numberOfSubscriptions).to.equal(1);
	});

	it(@"should dispose when the last subscription disposes", ^{
		RACDisposable *disposable1 = [signal subscribeNext:^(id _) {}];
		RACDisposable *disposable2 = [signal subscribeNext:^(id _) {}];
		
		[disposable2 dispose];
		expect(disposed).to.beFalsy();

		[disposable1 dispose];
		expect(disposed).to.beTruthy();
	});

	it(@"should reconnect after all the original subscriptions have been disposed", ^{
		RACDisposable *disposable = [signal subscribeNext:^(id _) {}];
		expect(numberOfSubscriptions).to.equal(1);
		
		[disposable dispose];
		expect(disposed).to.beTruthy();
		
		expect(numberOfSubscriptions).to.equal(0);

		disposed = NO;
		disposable = [signal subscribeNext:^(id _) {}];
		expect(numberOfSubscriptions).to.equal(1);
		[disposable dispose];
		expect(disposed).to.beTruthy();
	});
});

SpecEnd
