//
//  RACBindingSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "RACKVOProperty.h"
#import "RACDisposable.h"
#import "NSObject+RACKVOWrapper.h"

@interface TestClass : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) TestClass *relatedObject;
@end

@implementation TestClass
@end

SpecBegin(RACKVOProperty)

describe(@"RACBind", ^{
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
		expect(a.relatedObject != b.relatedObject).to.beTruthy();
	});
	
	it(@"should take the master's value at the start", ^{
		a.name = testName1;
		b.name = testName2;
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
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
	
	it(@"should bind even if the initial update is the same as the other object's value", ^{
		a.name = testName1;
		b.name = testName2;
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
		b.name = testName2;
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
	});
	
	it(@"should bind even if the initial update is the same as the receiver's value", ^{
		a.name = testName1;
		b.name = testName2;
		RACBind(a, name) = RACBind(b, name);
		expect(a.name).to.equal(testName2);
		expect(b.name).to.equal(testName2);
		b.name = testName1;
		expect(a.name).to.equal(testName1);
		expect(b.name).to.equal(testName1);
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
