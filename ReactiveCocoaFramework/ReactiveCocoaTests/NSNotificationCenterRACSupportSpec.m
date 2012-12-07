//
//  NSNotificationCenterRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSNotificationCenter+RACSupport.h"

static NSString * const TestNotification = @"TestNotification";

SpecBegin(NSNotificationCenterRACSupport)

__block NSNotificationCenter *notificationCenter;

beforeEach(^{
	// The compiler gets confused and thinks you might be messaging
	// NSDistributedNotificationCenter otherwise. Wtf?
	notificationCenter = NSNotificationCenter.defaultCenter;
});

it(@"should send the notification when posted by any object", ^{
	id<RACSignal> signal = [notificationCenter rac_addObserverForName:TestNotification object:nil];

	__block NSUInteger count = 0;
	[signal subscribeNext:^(NSNotification *notification) {
		++count;

		expect(notification).to.beKindOf(NSNotification.class);
		expect(notification.name).to.equal(TestNotification);
	}];

	expect(count).to.equal(0);

	[notificationCenter postNotificationName:TestNotification object:nil];
	expect(count).to.equal(1);

	[notificationCenter postNotificationName:TestNotification object:self];
	expect(count).to.equal(2);
});

it(@"should send the notification when posted by a specific object", ^{
	id<RACSignal> signal = [notificationCenter rac_addObserverForName:TestNotification object:self];

	__block NSUInteger count = 0;
	[signal subscribeNext:^(NSNotification *notification) {
		++count;

		expect(notification).to.beKindOf(NSNotification.class);
		expect(notification.name).to.equal(TestNotification);
		expect(notification.object).to.equal(self);
	}];

	expect(count).to.equal(0);

	[notificationCenter postNotificationName:TestNotification object:nil];
	expect(count).to.equal(0);

	[notificationCenter postNotificationName:TestNotification object:self];
	expect(count).to.equal(1);
});

SpecEnd
