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

		__block RACBinding *binding1;
		__block RACBinding *binding2;
		
		id value1 = @"test value 1";
		id value2 = @"test value 2";
		
		NSArray *values = @[value1, value2];
		// id value3 = @"test value 3";
		// NSArray *values = @[ value1, value2, value3 ];
		
		before(^{
			getBinding1 = data[RACBindingExamplesGetBindingBlock1];
			getBinding2 = data[RACBindingExamplesGetBindingBlock2];

			binding1 = getBinding1();
			binding2 = getBinding2();
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
		
		it(@"should receive values from subscribing", ^{
			NSMutableArray *receivedValues = [NSMutableArray array];
			RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
				[subscriber sendNext:value1];
				[subscriber sendNext:value2];
				return nil;
			}];
			
			[signal subscribe:binding2];
			
//			RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
//				[receivedValue addObject:x];
//			}];
			
			[binding1 subscribe:binding2];
			
			expect(receivedValues).to.equal(values);
		});
		
		it(@"should bind RACBindings together", ^{
			expect(@"Alas, it does not").to.equal(YES);
		});
		
		
	});
});

SharedExampleGroupsEnd
