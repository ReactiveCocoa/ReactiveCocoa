//
//  RACChannelExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACChannelExamples.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

NSString * const RACChannelExamples = @"RACChannelExamples";
NSString * const RACChannelExampleCreateBlock = @"RACChannelExampleCreateBlock";

NSString * const RACViewChannelExamples = @"RACViewChannelExamples";
NSString * const RACViewChannelExampleCreateTerminalBlock = @"RACViewChannelExampleCreateTerminalBlock";
NSString * const RACViewChannelExampleView = @"RACViewChannelExampleView";
NSString * const RACViewChannelExampleKeyPath = @"RACViewChannelExampleKeyPath";

SharedExampleGroupsBegin(RACChannelExamples)

sharedExamplesFor(RACChannelExamples, ^(NSDictionary *data) {
	__block RACChannel * (^getChannel)(void);
	__block RACChannel *channel;

	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		getChannel = data[RACChannelExampleCreateBlock];
		channel = getChannel();
	});
	
	it(@"should not send any leadingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[channel.followingTerminal sendNext:value1];
		[channel.leadingTerminal subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.beNil();
		
		[channel.followingTerminal sendNext:value2];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest followingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[channel.leadingTerminal sendNext:value1];
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[channel.leadingTerminal sendNext:value2];
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send leadingTerminal values as they change", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[channel.leadingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[channel.followingTerminal sendNext:value1];
		[channel.followingTerminal sendNext:value2];
		[channel.followingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send followingTerminal values as they change", ^{
		[channel.leadingTerminal sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[channel.followingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[channel.leadingTerminal sendNext:value2];
		[channel.leadingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the leadingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[channel.leadingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should complete both signals when the followingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[channel.followingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should replay completion to new subscribers", ^{
		[channel.leadingTerminal sendCompleted];

		__block BOOL completedLeft = NO;
		[channel.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[channel.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SharedExampleGroupsBegin(RACViewChannelExamples)

sharedExamplesFor(RACViewChannelExamples, ^(NSDictionary *data) {
	__block NSObject *testView;
	__block NSString *keyPath;
	__block RACChannelTerminal * (^getTerminal)(void);

	__block RACChannelTerminal *endpoint;

	beforeEach(^{
		testView = data[RACViewChannelExampleView];
		keyPath = data[RACViewChannelExampleKeyPath];
		getTerminal = data[RACViewChannelExampleCreateTerminalBlock];

		endpoint = getTerminal();
	});

	it(@"should not send changes made by the channel itself", ^{
		__block BOOL receivedNext = NO;
		[endpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();

		[endpoint sendNext:@"foo"];
		expect(receivedNext).to.beFalsy();

		[endpoint sendNext:@"bar"];
		expect(receivedNext).to.beFalsy();

		[endpoint sendCompleted];
		expect(receivedNext).to.beFalsy();
	});

	it(@"should not send progammatic changes made to the view", ^{
		__block BOOL receivedNext = NO;
		[endpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();

		[testView setValue:@"foo" forKeyPath:keyPath];
		expect(receivedNext).to.beFalsy();

		[testView setValue:@"bar" forKeyPath:keyPath];
		expect(receivedNext).to.beFalsy();
	});
});

SharedExampleGroupsEnd
