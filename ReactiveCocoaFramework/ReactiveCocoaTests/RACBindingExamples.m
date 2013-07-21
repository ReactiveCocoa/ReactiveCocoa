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
	
	it(@"should send the latest rumor on subscription", ^{
		__block id receivedValue = nil;

		[binding.rumorsSubscriber sendNext:value1];
		[[binding.rumorsSignal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.rumorsSubscriber sendNext:value2];
		[[binding.rumorsSignal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest fact on subscription", ^{
		__block id receivedValue = nil;

		[binding.factsSubscriber sendNext:value1];
		[[binding.factsSignal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.factsSubscriber sendNext:value2];
		[[binding.factsSignal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send rumors as they change", ^{
		[binding.rumorsSubscriber sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.rumorsSignal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.rumorsSubscriber sendNext:value2];
		[binding.rumorsSubscriber sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send facts as they change", ^{
		[binding.factsSubscriber sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.factsSignal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.factsSubscriber sendNext:value2];
		[binding.factsSubscriber sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the rumorsSubscriber is completed", ^{
		__block BOOL completedFacts = NO;
		[binding.factsSignal subscribeCompleted:^{
			completedFacts = YES;
		}];

		__block BOOL completedRumors = NO;
		[binding.rumorsSignal subscribeCompleted:^{
			completedRumors = YES;
		}];

		[binding.rumorsSubscriber sendCompleted];
		expect(completedFacts).to.beTruthy();
		expect(completedRumors).to.beTruthy();
	});

	it(@"should complete both signals when the factsSubscriber is completed", ^{
		__block BOOL completedFacts = NO;
		[binding.factsSignal subscribeCompleted:^{
			completedFacts = YES;
		}];

		__block BOOL completedRumors = NO;
		[binding.rumorsSignal subscribeCompleted:^{
			completedRumors = YES;
		}];

		[binding.factsSubscriber sendCompleted];
		expect(completedFacts).to.beTruthy();
		expect(completedRumors).to.beTruthy();
	});
});

SharedExampleGroupsEnd
