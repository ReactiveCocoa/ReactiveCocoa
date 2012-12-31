//
//  RACLazyPropertySpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACLazyProperty.h"
#import "RACPropertyExamples.h"

SpecBegin(RACLazyProperty)

describe(@"RACLazyProperty", ^{
	__block RACLazyProperty *property;
	__block BOOL didGenerateDefaultValue;
	NSString *defaultValue = @"default value";
	NSString *testValue = @"test value";
	
	before(^{
		didGenerateDefaultValue = NO;
		property = [RACLazyProperty lazyPropertyWithStart:[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			didGenerateDefaultValue = YES;
			[subscriber sendNext:defaultValue];
			[subscriber sendCompleted];
			return nil;
		}]];
	});
	
	itShouldBehaveLike(RACPropertyExamples, [^{ return [RACLazyProperty lazyPropertyWithStart:[RACSignal return:nil]]; } copy], nil);
	itShouldBehaveLike(RACPropertyMemoryManagementExamples, [^{ return [RACLazyProperty lazyPropertyWithStart:[RACSignal return:nil]]; } copy], nil);
	
	it(@"should send the default value on subscription", ^{
		__block id receivedValue = nil;
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(defaultValue);
		expect(didGenerateDefaultValue).to.beTruthy();
	});
	
	it(@"should generate the default value only once", ^{
		__block id receivedValue = nil;
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(defaultValue);
		expect(didGenerateDefaultValue).to.beTruthy();
		didGenerateDefaultValue = NO;
		receivedValue = nil;
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(defaultValue);
		expect(didGenerateDefaultValue).to.beFalsy();
	});
	
	it(@"should send the default value to bindings on subscription", ^{
		__block id receivedValue = nil;
		[[[property binding] take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(defaultValue);
	});
	
	it(@"shouldn't generate the default value if it gets overwritten", ^{
		__block id receivedValue = nil;
		[property sendNext:testValue];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = testValue;
		}];
		expect(receivedValue).to.equal(testValue);
		expect(didGenerateDefaultValue).to.beFalsy();
	});
	
	it(@"shouldn't generate the default value if it gets overwritten by a binding", ^{
		__block id receivedValue = nil;
		[[property binding] sendNext:testValue];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = testValue;
		}];
		expect(receivedValue).to.equal(testValue);
		expect(didGenerateDefaultValue).to.beFalsy();
	});
	
	describe(@"-nonLazyValues", ^{
		__block RACSignal *nonLazyValues;
		
		before(^{
			nonLazyValues = [property nonLazyValues];
		});
		
		it(@"shouldn't trigger default value generation on subscription", ^{
			__block BOOL didReceiveValue = NO;
			[nonLazyValues subscribeNext:^(id x) {
				didReceiveValue = YES;
			}];
			expect(didReceiveValue).to.beFalsy();
			expect(didGenerateDefaultValue).to.beFalsy();
		});
		
		it(@"should send changes", ^{
			__block id receivedValue = nil;
			[nonLazyValues subscribeNext:^(id x) {
				receivedValue = x;
			}];
			[property sendNext:testValue];
			expect(receivedValue).to.equal(testValue);
			expect(didGenerateDefaultValue).to.beFalsy();
		});
		
		it(@"should send the current value if it's not the default value", ^{
			__block id receivedValue = nil;
			[property sendNext:testValue];
			[nonLazyValues subscribeNext:^(id x) {
				receivedValue = x;
			}];
			expect(receivedValue).to.equal(testValue);
			expect(didGenerateDefaultValue).to.beFalsy();
		});
	});
});

SpecEnd
