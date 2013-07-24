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

		[binding.endpointForRumors sendNext:value1];
		[[binding.endpointForFacts take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.endpointForRumors sendNext:value2];
		[[binding.endpointForFacts take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send the latest fact on subscription", ^{
		__block id receivedValue = nil;

		[binding.endpointForFacts sendNext:value1];
		[[binding.endpointForRumors take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value1);
		
		[binding.endpointForFacts sendNext:value2];
		[[binding.endpointForRumors take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send rumors as they change", ^{
		[binding.endpointForRumors sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.endpointForFacts subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.endpointForRumors sendNext:value2];
		[binding.endpointForRumors sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should send facts as they change", ^{
		[binding.endpointForFacts sendNext:value1];

		NSMutableArray *receivedValues = [NSMutableArray array];
		[binding.endpointForRumors subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		[binding.endpointForFacts sendNext:value2];
		[binding.endpointForFacts sendNext:value3];
		expect(receivedValues).to.equal(values);
	});

	it(@"should complete both signals when the endpointForRumors is completed", ^{
		__block BOOL completedFacts = NO;
		[binding.endpointForRumors subscribeCompleted:^{
			completedFacts = YES;
		}];

		__block BOOL completedRumors = NO;
		[binding.endpointForFacts subscribeCompleted:^{
			completedRumors = YES;
		}];

		[binding.endpointForRumors sendCompleted];
		expect(completedFacts).to.beTruthy();
		expect(completedRumors).to.beTruthy();
	});

	it(@"should complete both signals when the endpointForFacts is completed", ^{
		__block BOOL completedFacts = NO;
		[binding.endpointForRumors subscribeCompleted:^{
			completedFacts = YES;
		}];

		__block BOOL completedRumors = NO;
		[binding.endpointForFacts subscribeCompleted:^{
			completedRumors = YES;
		}];

		[binding.endpointForFacts sendCompleted];
		expect(completedFacts).to.beTruthy();
		expect(completedRumors).to.beTruthy();
	});
});

SharedExampleGroupsEnd
