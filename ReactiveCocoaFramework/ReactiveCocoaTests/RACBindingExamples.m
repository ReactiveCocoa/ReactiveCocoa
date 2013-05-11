//
//  RACBindingExamples.m
//  ReactiveCocoa
//
//  Created by Maxwell Swadling on 11/05/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubjectExamples.h"
#import "RACDisposable.h"
#import "RACPropertySubject.h"
#import "RACBinding.h"
#import "NSObject+RACPropertySubscribing.h"

NSString * const RACBindingExamples = @"RACBindingExamples";
NSString * const RACBindingExamplesGetBindingBlock1 = @"RACBindingExamplesGetBindingBlock1";
NSString * const RACBindingExamplesGetBindingBlock2 = @"RACBindingExamplesGetBindingBlock2";
NSString * const RACBindingExamplesGetProperty = @"RACBindingExamplesGetProperty";

SharedExampleGroupsBegin(RACBindingExamples)

sharedExamplesFor(RACBindingExamples, ^(NSDictionary *data) {
	
	describe(@"bindings", ^{
		__block RACBinding *(^getBinding1)(void);
		__block RACBinding *(^getBinding2)(void);
		// Properties are only used for their RACSignal <RACSubscriber> methods
		__block RACSignal <RACSubscriber> *(^getProperty)(void);

		__block RACBinding *binding1;
		__block RACBinding *binding2;
		__block RACSignal <RACSubscriber> *property;
		
		id value1 = @"test value 1";
		id value2 = @"test value 2";
		id value3 = @"test value 3";
		NSArray *values = @[ value1, value2, value3 ];
		
		before(^{
			getBinding1 = data[RACBindingExamplesGetBindingBlock1];
			getBinding2 = data[RACBindingExamplesGetBindingBlock2];
			getProperty = data[RACBindingExamplesGetProperty];

			binding1 = getBinding1();
			binding2 = getBinding2();
			property = getProperty();
		});
		
		it(@"should send the property's current value on subscription", ^{
			__block id receivedValue = nil;
			[property sendNext:value1];
			[[binding1 take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[property sendNext:value2];
			[[binding1 take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
		
		it(@"should send the current value on subscription even if it was set by itself", ^{
			__block id receivedValue = nil;
			[binding1 sendNext:value1];
			[[binding1 take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[binding1 sendNext:value2];
			[[binding1 take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
		
		it(@"should send the property's value as it changes if it was set by the property", ^{
			[property sendNext:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 subscribeNext:^(id x) {
				[receivedValues addObject:x];
			}];
			[property sendNext:value2];
			[property sendNext:value3];
			expect(receivedValues).to.equal(values);
		});
		
		it(@"should not send the property's value as it changes if it was set by itself", ^{
			[property sendNext:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 subscribeNext:^(id x) {
				[receivedValues addObject:x];
			}];
			[binding1 sendNext:value2];
			[binding1 sendNext:value3];
			expect(receivedValues).to.equal(@[ value1 ]);
		});
		
		it(@"should send the property's value as it changes if it was set by another binding", ^{
			[property sendNext:value1];
			NSMutableArray *receivedValues1 = [NSMutableArray array];
			[binding1 subscribeNext:^(id x) {
				[receivedValues1 addObject:x];
			}];
			NSMutableArray *receivedValues2 = [NSMutableArray array];
			[binding2 subscribeNext:^(id x) {
				[receivedValues2 addObject:x];
			}];
			[binding1 sendNext:value2];
			[binding2 sendNext:value3];
			NSArray *expectedValues1 = @[ value1, value3 ];
			NSArray *expectedValues2 = @[ value1, value2 ];
			expect(receivedValues1).to.equal(expectedValues1);
			expect(receivedValues2).to.equal(expectedValues2);
		});
		
		it(@"should set the property's value to values it's sent", ^{
			__block id receivedValue = nil;
			[binding1 sendNext:value1];
			[[property take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[binding1 sendNext:value2];
			[[property take:1] subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
	});
});

SharedExampleGroupsEnd
