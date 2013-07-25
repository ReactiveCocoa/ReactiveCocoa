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
NSString * const RACViewBindingExampleCreateEndpointBlock = @"RACViewBindingExampleCreateEndpointBlock";
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
	
	it(@"should not send any leadingEndpoint value on subscription", ^{
		__block id receivedValue = nil;

		[binding.followingEndpoint sendNext:value1];
		[binding.leadingEndpoint subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.beNil();
		
		[binding.followingEndpoint sendNext:value2];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest followingEndpoint value on subscription", ^{
		__block id receivedValue = nil;

		[binding.leadingEndpoint sendNext:value1];
		[[binding.followingEndpoint take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.leadingEndpoint sendNext:value2];
		[[binding.followingEndpoint take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send leadingEndpoint values as they change", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.leadingEndpoint subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.followingEndpoint sendNext:value1];
		[binding.followingEndpoint sendNext:value2];
		[binding.followingEndpoint sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send followingEndpoint values as they change", ^{
		[binding.leadingEndpoint sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.followingEndpoint subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.leadingEndpoint sendNext:value2];
		[binding.leadingEndpoint sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the leadingEndpoint is completed", ^{
		__block BOOL completedLeft = NO;
		[binding.leadingEndpoint subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingEndpoint subscribeCompleted:^{
			completedRight = YES;
		}];

		[binding.leadingEndpoint sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should complete both signals when the followingEndpoint is completed", ^{
		__block BOOL completedLeft = NO;
		[binding.leadingEndpoint subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingEndpoint subscribeCompleted:^{
			completedRight = YES;
		}];

		[binding.followingEndpoint sendCompleted];
		expect(completedLeft).to.beTruthy();
		expect(completedRight).to.beTruthy();
	});

	it(@"should replay completion to new subscribers", ^{
		[binding.leadingEndpoint sendCompleted];

		__block BOOL completedLeft = NO;
		[binding.leadingEndpoint subscribeCompleted:^{
			completedLeft = YES;
		}];

		__block BOOL completedRight = NO;
		[binding.followingEndpoint subscribeCompleted:^{
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
	__block RACBindingEndpoint * (^getEndpoint)(void);

	__block RACBindingEndpoint *endpoint;

	beforeEach(^{
		testView = data[RACViewBindingExampleView];
		keyPath = data[RACViewBindingExampleKeyPath];
		getEndpoint = data[RACViewBindingExampleCreateEndpointBlock];

		endpoint = getEndpoint();
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
