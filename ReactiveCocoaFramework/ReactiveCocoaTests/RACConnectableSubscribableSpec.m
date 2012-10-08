//
//  RACConnectableSubscribableSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACConnectableSubscribable.h"
#import "RACDisposable.h"
#import "RACSubscriber.h"

SpecBegin(RACConnectableSubscribable)

describe(@"-autoconnect", ^{
	__block BOOL disposed = NO;
	__block NSUInteger numberOfSubscriptions = 0;
	__block RACSubscribable *subscribable;

	beforeEach(^{
		disposed = NO;
		numberOfSubscriptions = 0;
		subscribable = [[[RACConnectableSubscribable
			createSubscribable:^(id<RACSubscriber> subscriber) {
				numberOfSubscriptions++;

				return [RACDisposable disposableWithBlock:^{
					numberOfSubscriptions--;
					disposed = YES;
				}];
			}]
		publish]
		autoconnect];
	});

	it(@"should connect to the underlying subscribable on the first subscription", ^{
		[subscribable subscribeNext:^(id _) {}];

		expect(numberOfSubscriptions).to.equal(1);
	});

	it(@"shouldn't reconnect for more subscriptions", ^{
		[subscribable subscribeNext:^(id _) {}];
		[subscribable subscribeNext:^(id _) {}];

		expect(numberOfSubscriptions).to.equal(1);
	});

	it(@"should dispose when the last subscription disposes", ^{
		RACDisposable *disposable1 = [subscribable subscribeNext:^(id _) {}];
		RACDisposable *disposable2 = [subscribable subscribeNext:^(id _) {}];
		
		[disposable2 dispose];
		expect(disposed).to.beFalsy();

		[disposable1 dispose];
		expect(disposed).to.beTruthy();
	});

	it(@"should reconnect after all the original subscriptions have been disposed", ^{
		RACDisposable *disposable = [subscribable subscribeNext:^(id _) {}];
		expect(numberOfSubscriptions).to.equal(1);
		
		[disposable dispose];
		expect(disposed).to.beTruthy();
		
		expect(numberOfSubscriptions).to.equal(0);

		disposed = NO;
		disposable = [subscribable subscribeNext:^(id _) {}];
		expect(numberOfSubscriptions).to.equal(1);
		[disposable dispose];
		expect(disposed).to.beTruthy();
	});
});

SpecEnd
