//
//  RACPropertySubjectExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubjectExamples.h"
#import "RACDisposable.h"
#import "RACPropertySubject.h"
#import "RACBinding.h"
#import "NSObject+RACPropertySubscribing.h"

NSString * const RACPropertySubjectExamples = @"RACPropertySubjectExamples";
NSString * const RACPropertySubjectExampleGetPropertyBlock = @"RACPropertySubjectExampleGetPropertyBlock";

SharedExampleGroupsBegin(RACPropertySubjectExamples)

sharedExamplesFor(RACPropertySubjectExamples, ^(NSDictionary *data) {
	__block RACPropertySubject *(^getProperty)(void);
	__block RACPropertySubject *property;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		getProperty = data[RACPropertySubjectExampleGetPropertyBlock];
		property = getProperty();
	});
	
	it(@"should send it's current value on subscription", ^{
		__block id receivedValue = nil;
		[property didUpdateWithNewValue:value1];
		[[property streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
		
		[property didUpdateWithNewValue:value2];
		[[property streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send it's value as it changes", ^{
		[property didUpdateWithNewValue:value1];
		NSMutableArray *receivedValues = [NSMutableArray array];
		[property observerWithUpdateHandler:^(id x) {
			[receivedValues addObject:x];
		}];
		[property didUpdateWithNewValue:value2];
		[property didUpdateWithNewValue:value3];
		expect(receivedValues).to.equal(values);
	});
	
	describe(@"memory management", ^{
		it(@"should dealloc when it's subscribers are disposed", ^{
			RACDisposable *disposable = nil;
			__block BOOL deallocd = NO;
			@autoreleasepool {
				RACPropertySubject *property __attribute__((objc_precise_lifetime)) = getProperty();
				[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];
				disposable = [property observerWithUpdateHandler:^(id x) {}];
			}
			[disposable dispose];
			expect(deallocd).will.beTruthy();
		});
		
		it(@"should dealloc when it's subscriptions are disposed", ^{
			RACDisposable *disposable = nil;
			__block BOOL deallocd = NO;
			@autoreleasepool {
				RACPropertySubject *property __attribute__((objc_precise_lifetime)) = getProperty();
				[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];
				disposable = [RACSignal.signalWithoutSubscriptionHandler subscribe:property];
			}
			[disposable dispose];
			expect(deallocd).will.beTruthy();
		});
		
		it(@"should dealloc when it's binding's subscribers are disposed", ^{
			RACDisposable *disposable = nil;
			__block BOOL deallocd = NO;
			@autoreleasepool {
				RACPropertySubject *property __attribute__((objc_precise_lifetime)) = getProperty();
				[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];
				disposable = [[property binding] observerWithUpdateHandler:^(id x) {}];
			}
			[disposable dispose];
			expect(deallocd).will.beTruthy();
		});
		
		it(@"should dealloc when it's binding's subscriptions are disposed", ^{
			RACDisposable *disposable = nil;
			__block BOOL deallocd = NO;
			@autoreleasepool {
				RACPropertySubject *property __attribute__((objc_precise_lifetime)) = getProperty();
				[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];
				disposable = [RACSignal.signalWithoutSubscriptionHandler subscribe:[property binding]];
			}
			[disposable dispose];
			expect(deallocd).will.beTruthy();
		});
		
		it(@"should dealloc if it's binding with other properties is disposed", ^{
			RACDisposable *disposable = nil;
			__block BOOL deallocd1 = NO;
			__block BOOL deallocd2 = NO;
			@autoreleasepool {
				RACPropertySubject *property1 __attribute__((objc_precise_lifetime)) = getProperty();
				RACPropertySubject *property2 __attribute__((objc_precise_lifetime)) = getProperty();
				[property1 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd1 = YES;
				}]];
				[property2 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd2 = YES;
				}]];
				disposable = [[property1 binding] disposableWithBinding:[property2 binding]];
			}
			[disposable dispose];
			expect(deallocd1).will.beTruthy();
			expect(deallocd2).will.beTruthy();
		});
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
			[property didUpdateWithNewValue:value1];
			[[binding1 streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[property didUpdateWithNewValue:value2];
			[[binding1 streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
		
		it(@"should send the current value on subscription even if it was set by itself", ^{
			__block id receivedValue = nil;
			[binding1 didUpdateWithNewValue:value1];
			[[binding1 streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[binding1 didUpdateWithNewValue:value2];
			[[binding1 streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
		
		it(@"should send the property's value as it changes if it was set by the property", ^{
			[property didUpdateWithNewValue:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 observerWithUpdateHandler:^(id x) {
				[receivedValues addObject:x];
			}];
			[property didUpdateWithNewValue:value2];
			[property didUpdateWithNewValue:value3];
			expect(receivedValues).to.equal(values);
		});
		
		it(@"should not send the property's value as it changes if it was set by itself", ^{
			[property didUpdateWithNewValue:value1];
			NSMutableArray *receivedValues = [NSMutableArray array];
			[binding1 observerWithUpdateHandler:^(id x) {
				[receivedValues addObject:x];
			}];
			[binding1 didUpdateWithNewValue:value2];
			[binding1 didUpdateWithNewValue:value3];
			expect(receivedValues).to.equal(@[ value1 ]);
		});
		
		it(@"should send the property's value as it changes if it was set by another binding", ^{
			[property didUpdateWithNewValue:value1];
			NSMutableArray *receivedValues1 = [NSMutableArray array];
			[binding1 observerWithUpdateHandler:^(id x) {
				[receivedValues1 addObject:x];
			}];
			NSMutableArray *receivedValues2 = [NSMutableArray array];
			[binding2 observerWithUpdateHandler:^(id x) {
				[receivedValues2 addObject:x];
			}];
			[binding1 didUpdateWithNewValue:value2];
			[binding2 didUpdateWithNewValue:value3];
			NSArray *expectedValues1 = @[ value1, value3 ];
			NSArray *expectedValues2 = @[ value1, value2 ];
			expect(receivedValues1).to.equal(expectedValues1);
			expect(receivedValues2).to.equal(expectedValues2);
		});

		it(@"should set the property's value to values it's sent", ^{
			__block id receivedValue = nil;
			[binding1 didUpdateWithNewValue:value1];
			[[property streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value1);
			
			[binding1 didUpdateWithNewValue:value2];
			[[property streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(value2);
		});
	});
});

SharedExampleGroupsEnd
