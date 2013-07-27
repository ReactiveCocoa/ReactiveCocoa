//
//  RACBindingExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBindingExamples.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

NSString * const RACBindingExamples = @"RACBindingExamples";
NSString * const RACBindingExampleCreateBlock = @"RACBindingExampleCreateBlock";

NSString * const RACViewBindingExamples = @"RACViewBindingExamples";
NSString * const RACViewBindingExampleCreateTerminalBlock = @"RACViewBindingExampleCreateTerminalBlock";
NSString * const RACViewBindingExampleView = @"RACViewBindingExampleView";
NSString * const RACViewBindingExampleKeyPath = @"RACViewBindingExampleKeyPath";

SharedExampleGroupsBegin(RACBindingExamples)

sharedExamplesFor(RACBindingExamples, ^(NSDictionary *data) {
	__block RACBinding * (^getBinding)(void);
	__block RACBinding *binding;

	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		getBinding = data[RACBindingExampleCreateBlock];
		binding = getBinding();
	});
	
	it(@"should not send any leadingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[binding.followingTerminal sendNext:value1];
		[binding.leadingTerminal subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.beNil();
		
		[binding.followingTerminal sendNext:value2];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest followingTerminal value on subscription", ^{
		__block id receivedValue = nil;

		[binding.leadingTerminal sendNext:value1];
		[[binding.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.leadingTerminal sendNext:value2];
		[[binding.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send leadingTerminal values as they change", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.leadingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.followingTerminal sendNext:value1];
		[binding.followingTerminal sendNext:value2];
		[binding.followingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send followingTerminal values as they change", ^{
		[binding.leadingTerminal sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.followingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.leadingTerminal sendNext:value2];
		[binding.leadingTerminal sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the leadingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[binding.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[binding.leadingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should complete both signals when the followingTerminal is completed", ^{
		__block BOOL completedLeft = NO;
		[binding.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		[binding.followingTerminal sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should replay completion to new subscribers", ^{
		[binding.leadingTerminal sendCompleted];

		__block BOOL completedLeft = NO;
		[binding.leadingTerminal subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingTerminal subscribeCompleted:^{
			completedRight = YES;
		}];

		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SharedExampleGroupsBegin(RACViewBindingExamples)

sharedExamplesFor(RACViewBindingExamples, ^(NSDictionary *data) {
	__block NSObject *testView;
	__block NSString *keyPath;
	__block RACBindingTerminal * (^getTerminal)(void);

	__block RACBindingTerminal *endpoint;

	beforeEach(^{
		testView = data[RACViewBindingExampleView];
		keyPath = data[RACViewBindingExampleKeyPath];
		getTerminal = data[RACViewBindingExampleCreateTerminalBlock];

		endpoint = getTerminal();
	});

	it(@"should not send changes made by the binding itself", ^{
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
