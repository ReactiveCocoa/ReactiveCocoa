//
//  RACKVOPropertySpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACKVOProperty.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACTestObject.h"
#import "RACPropertySignalExamples.h"
#import "RACPropertyExamples.h"

@interface TestClass : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) TestClass *relatedObject;
@end

@implementation TestClass
@end

SpecBegin(RACKVOProperty)

describe(@"RACKVOProperty", ^{
	__block TestClass *object;
	__block RACKVOProperty *property;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		object = [[TestClass alloc] init];
		property = [RACKVOProperty propertyWithTarget:object keyPath:@keypath(object.name)];
	});
	
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, RACSignal *signal) {
		[signal subscribe:[RACKVOProperty propertyWithTarget:testObject keyPath:keyPath]];
	};
	
	itShouldBehaveLike(RACPropertySignalExamples, @{ RACPropertySignalExamplesSetupBlock: setupBlock }, nil);
	
	itShouldBehaveLike(RACPropertyExamples, [^{ return [RACKVOProperty propertyWithTarget:object keyPath:@keypath(object.name)]; } copy], nil);
	
	it(@"should send the object's current value when subscribed to", ^{
		__block id receivedValue = @"received value should not be this";
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.beNil();
		
		object.name = value1;
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
	});
	
	it(@"should send the object's new value when it's changed", ^{
		object.name = value1;
		NSMutableArray *receivedValues = [NSMutableArray array];
		[property subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		object.name = value2;
		object.name = value3;
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should set values it's sent", ^{
		expect(object.name).to.beNil();
		[property sendNext:value1];
		expect(object.name).to.equal(value1);
		[property sendNext:value2];
		expect(object.name).to.equal(value2);
	});
	
	it(@"should be able to subscribe to signals", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[object rac_addObserver:self forKeyPath:@keypath(object.name) options:NSKeyValueObservingOptionNew queue:nil block:^(id observer, NSDictionary *change) {
			[receivedValues addObject:change[NSKeyValueChangeNewKey]];
		}];
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:value1];
			[subscriber sendNext:value2];
			[subscriber sendNext:value3];
			return nil;
		}];
		[signal subscribe:property];
		expect(receivedValues).to.equal(values);
	});
});

describe(@"RACKVOProperty bindings", ^{
	__block TestClass *a;
	__block TestClass *b;
	__block TestClass *c;
	__block NSString *testName1;
	__block NSString *testName2;
	__block NSString *testName3;
	
	before(^{
		a = [[TestClass alloc] init];
		b = [[TestClass alloc] init];
		c = [[TestClass alloc] init];
		testName1 = @"sync it!";
		testName2 = @"sync it again!";
		testName3 = @"sync it once more!";
	});
	
	it(@"should keep objects' properties in sync", ^{
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.beNil();
		expect(b.name).to.beNil();
		
		a.name = testName1;
		expect(a.name).to.equal(testName1);
		expect(b.name).to.equal(testName1);
		
		b.name = testName2;
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
		
		a.name = nil;
		expect(a.name).to.beNil();
		expect(b.name).to.beNil();
	});
	
	it(@"should keep properties identified by keypaths in sync", ^{
		RACBind(a, relatedObject.name) = RACBind(b, relatedObject.name);
		a.relatedObject = [[TestClass alloc] init];
		b.relatedObject = [[TestClass alloc] init];
		
		a.relatedObject.name = testName1;
		expect(a.relatedObject.name).to.equal(testName1);
		expect(b.relatedObject.name).to.equal(testName1);
		expect(a.relatedObject != b.relatedObject).to.beTruthy();
		
		b.relatedObject = nil;
		expect(a.relatedObject.name).to.beNil();
		
		c.name = testName2;
		b.relatedObject = c;
		expect(a.relatedObject.name).to.equal(testName2);
		expect(b.relatedObject.name).to.equal(testName2);
		expect(a.relatedObject).notTo.equal(b.relatedObject);
	});
	
	it(@"should take the value of the object being bound to at the start", ^{
		a.name = testName1;
		b.name = testName2;
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
	});
	
	it(@"should update the value even if it's the same value the object had before it was bound", ^{
		a.name = testName1;
		b.name = testName2;
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
		
		b.name = testName1;
		expect(a.name).to.equal(testName1);
		expect(b.name).to.equal(testName1);
	});
	
	it(@"should bind transitively", ^{
		a.name = testName1;
		b.name = testName2;
		c.name = testName3;
		RACBind(a, name) = RACBind(b, name);
		RACBind(b, name) = RACBind(c, name);
		expect(a.name).to.equal(testName3);
		expect(b.name).to.equal(testName3);
		expect(c.name).to.equal(testName3);
		
		c.name = testName1;
		expect(a.name).to.equal(testName1);
		expect(b.name).to.equal(testName1);
		expect(c.name).to.equal(testName1);
		
		b.name = testName2;
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
		expect(c.name).to.equal(testName2);
		
		a.name = testName3;
		expect(a.name).to.equal(testName3);
		expect(b.name).to.equal(testName3);
		expect(c.name).to.equal(testName3);
	});
	
	it(@"should not interfere with or be interfered by KVO callbacks", ^{
		__block BOOL firstObserverShouldChangeName = YES;
		__block BOOL secondObserverShouldChangeName = YES;
		__block BOOL thirdObserverShouldChangeName = YES;
		__block BOOL fourthObserverShouldChangeName = YES;
		__block BOOL observerIsSettingValue = NO;
		[a rac_addObserver:self forKeyPath:@keypath(a.name) options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew queue:nil block:^(id observer, NSDictionary *change) {
			if (observerIsSettingValue) return;
			if (firstObserverShouldChangeName) {
				firstObserverShouldChangeName = NO;
				observerIsSettingValue = YES;
				a.name = testName1;
				observerIsSettingValue = NO;
			}
		}];
		[a rac_addObserver:self forKeyPath:@keypath(a.name) options:NSKeyValueObservingOptionOld queue:nil block:^(id observer, NSDictionary *change) {
			if (observerIsSettingValue) return;
			if (secondObserverShouldChangeName) {
				secondObserverShouldChangeName = NO;
				observerIsSettingValue = YES;
				a.name = testName2;
				observerIsSettingValue = NO;
			}
		}];
		RACBind(a, name) = RACBind(b, name);
		[a rac_addObserver:self forKeyPath:@keypath(a.name) options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew queue:nil block:^(id observer, NSDictionary *change) {
			if (observerIsSettingValue) return;
			if (thirdObserverShouldChangeName) {
				thirdObserverShouldChangeName = NO;
				observerIsSettingValue = YES;
				a.name = testName1;
				observerIsSettingValue = NO;
			}
		}];
		[a rac_addObserver:self forKeyPath:@keypath(a.name) options:NSKeyValueObservingOptionOld queue:nil block:^(id observer, NSDictionary *change) {
			if (observerIsSettingValue) return;
			if (fourthObserverShouldChangeName) {
				fourthObserverShouldChangeName = NO;
				observerIsSettingValue = YES;
				a.name = testName2;
				observerIsSettingValue = NO;
			}
		}];
		a.name = testName3;
		expect(firstObserverShouldChangeName).to.beFalsy();
		expect(secondObserverShouldChangeName).to.beFalsy();
		expect(thirdObserverShouldChangeName).to.beFalsy();
		expect(fourthObserverShouldChangeName).to.beFalsy();
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
	});
	
	it(@"should stop binding when disposed", ^{
		RACDisposable *disposable = [RACBind(a, name) bindTo:RACBind(b, name)];
		a.name = testName1;
		expect(a.name).to.equal(testName1);
		expect(b.name).to.equal(testName1);
		[disposable dispose];
		a.name = testName2;
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName1);
	});
});

SpecEnd
