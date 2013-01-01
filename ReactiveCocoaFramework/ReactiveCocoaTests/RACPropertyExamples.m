//
//  RACPropertyExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertyExamples.h"
#import "RACDisposable.h"
#import "RACProperty.h"
#import "RACBinding.h"
#import "NSObject+RACPropertySubscribing.h"

NSString * const RACPropertyExamples = @"RACPropertyExamples";
NSString * const RACPropertyMemoryManagementExamples = @"RACPropertyMemoryManagementExamples";

SharedExampleGroupsBegin(RACPropertyExamples)

sharedExamplesFor(RACPropertyExamples, ^(RACProperty *(^getProperty)(void)) {
	__block RACProperty *property;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		property = getProperty();
	});
	
	it(@"should send it's current value on subscription", ^{
		__block id receivedValue = nil;
		[property sendNext:value1];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
		
		[property sendNext:value2];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send it's value as it changes", ^{
		[property sendNext:value1];
		NSMutableArray *receivedValues = [NSMutableArray array];
		[property subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		[property sendNext:value2];
		[property sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
	describe(@"bindings", ^{
		__block RACBinding *binding1;
		__block RACBinding *binding2;
		
		before(^{
			binding1 = [property binding];
			binding2 = [property binding];
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
		
		it(@"should send the property's value as it changes", ^{
			[property sendNext:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 subscribeNext:^(id x) {
				[receivedValues addObject:x];
			}];
			[property sendNext:value2];
			[property sendNext:value3];
			expect(receivedValues).to.equal(values);
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
		
		it(@"should not echo changes it makes to it's subscribers", ^{
			[property sendNext:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 subscribeNext:^(id x) {
				[receivedValues addObject:x];
			}];
			[binding1 sendNext:value2];
			[binding1 sendNext:value3];
			expect(receivedValues).to.equal(@[ value1 ]);
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
		
		it(@"different bindings should work independently", ^{
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
	});
});

sharedExamplesFor(RACPropertyMemoryManagementExamples, ^(RACProperty *(^getProperty)(void)) {
	it(@"should dealloc when it's subscribers are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = getProperty();
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [property subscribeNext:^(id x) {
				
			}];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc when it's subscriptions are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			return nil;
		}];
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = getProperty();
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [signal subscribe:property];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc when it's binding's subscribers are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = getProperty();
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [[property binding] subscribeNext:^(id x) {
				
			}];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc when it's binding's subscriptions are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			return nil;
		}];
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = getProperty();
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [signal subscribe:[property binding]];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc if it's binding with other properties is disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd1 = NO;
		__block BOOL deallocd2 = NO;
		@autoreleasepool {
			RACProperty *property1 __attribute__((objc_precise_lifetime)) = getProperty();
			RACProperty *property2 __attribute__((objc_precise_lifetime)) = getProperty();
			[property1 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd1 = YES;
			}]];
			[property2 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd2 = YES;
			}]];
			disposable = [[property1 binding] bindTo:[property2 binding]];
		}
		[disposable dispose];
		expect(deallocd1).will.beTruthy();
		expect(deallocd2).will.beTruthy();
	});
});

SharedExampleGroupsEnd
