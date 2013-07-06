//
//  RACObservablePropertySubjectSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"
#import "RACPropertySignalExamples.h"
#import "RACPropertySubjectExamples.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACObservablePropertySubject.h"

SpecBegin(RACObservablePropertySubject)

describe(@"RACObservablePropertySubject", ^{
	__block RACTestObject *object;
	__block RACObservablePropertySubject *property;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		object = [[RACTestObject alloc] init];
		property = [RACObservablePropertySubject propertyWithTarget:object keyPath:@keypath(object.stringValue)];
	});
	
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, RACSignal *signal) {
		[signal subscribe:[RACObservablePropertySubject propertyWithTarget:testObject keyPath:keyPath]];
	};
	
	itShouldBehaveLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});
	
	itShouldBehaveLike(RACPropertySubjectExamples, ^{
		return @{
			RACPropertySubjectExampleGetPropertyBlock: [^{ return [RACObservablePropertySubject propertyWithTarget:object keyPath:@keypath(object.stringValue)]; } copy]
		};
	});
	
	it(@"should send the object's current value when subscribed to", ^{
		__block id receivedValue = @"received value should not be this";
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.beNil();
		
		object.stringValue = value1;
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
	});
	
	it(@"should send the object's new value when it's changed", ^{
		object.stringValue = value1;
		NSMutableArray *receivedValues = [NSMutableArray array];
		[property subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		object.stringValue = value2;
		object.stringValue = value3;
		expect(receivedValues).to.equal(values);
	});
	
	it(@"should set values it's sent", ^{
		expect(object.stringValue).to.beNil();
		[property sendNext:value1];
		expect(object.stringValue).to.equal(value1);
		[property sendNext:value2];
		expect(object.stringValue).to.equal(value2);
	});
	
	it(@"should be able to subscribe to signals", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[object rac_observeKeyPath:@keypath(object.stringValue) options:0 observer:self block:^(id value, NSDictionary *change) {
			[receivedValues addObject:value];
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

	it(@"should complete when the target deallocates", ^{
		__block BOOL deallocated = NO;
		__block BOOL completed = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			[[RACObservablePropertySubject propertyWithTarget:object keyPath:@keypath(object.stringValue)] subscribeCompleted:^{
				completed = YES;
			}];

			expect(deallocated).to.beFalsy();
			expect(completed).to.beFalsy();
		}

		expect(deallocated).to.beTruthy();
		expect(completed).to.beTruthy();
	});
});

describe(@"RACObservablePropertySubject bindings", ^{
	__block RACTestObject *a;
	__block RACTestObject *b;
	__block RACTestObject *c;
	__block NSString *testName1;
	__block NSString *testName2;
	__block NSString *testName3;
	
	before(^{
		a = [[RACTestObject alloc] init];
		b = [[RACTestObject alloc] init];
		c = [[RACTestObject alloc] init];
		testName1 = @"sync it!";
		testName2 = @"sync it again!";
		testName3 = @"sync it once more!";
	});
	
	it(@"should keep objects' properties in sync", ^{
		RACBind(a, stringValue) = RACBind(b, stringValue);
		expect(a.stringValue).to.beNil();
		expect(b.stringValue).to.beNil();
		
		a.stringValue = testName1;
		expect(a.stringValue).to.equal(testName1);
		expect(b.stringValue).to.equal(testName1);
		
		b.stringValue = testName2;
		expect(a.stringValue).to.equal(testName2);
		expect(b.stringValue).to.equal(testName2);
		
		a.stringValue = nil;
		expect(a.stringValue).to.beNil();
		expect(b.stringValue).to.beNil();
	});
	
	it(@"should keep properties identified by keypaths in sync", ^{
		RACBind(a, strongTestObjectValue.stringValue) = RACBind(b, strongTestObjectValue.stringValue);
		a.strongTestObjectValue = [[RACTestObject alloc] init];
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		
		a.strongTestObjectValue.stringValue = testName1;
		expect(a.strongTestObjectValue.stringValue).to.equal(testName1);
		expect(b.strongTestObjectValue.stringValue).to.equal(testName1);
		expect(a.strongTestObjectValue).notTo.equal(b.strongTestObjectValue);
		
		b.strongTestObjectValue = nil;
		expect(a.strongTestObjectValue.stringValue).to.beNil();
		
		c.stringValue = testName2;
		b.strongTestObjectValue = c;
		expect(a.strongTestObjectValue.stringValue).to.equal(testName2);
		expect(b.strongTestObjectValue.stringValue).to.equal(testName2);
		expect(a.strongTestObjectValue).notTo.equal(b.strongTestObjectValue);
	});
	
	it(@"should update properties identified by keypaths when the intermediate values change", ^{
		RACBind(a, strongTestObjectValue.stringValue) = RACBind(b, strongTestObjectValue.stringValue);
		a.strongTestObjectValue = [[RACTestObject alloc] init];
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		c.stringValue = testName1;
		b.strongTestObjectValue = c;
		
		expect(a.strongTestObjectValue.stringValue).to.equal(testName1);
		expect(a.strongTestObjectValue).notTo.equal(b.strongTestObjectValue);
	});
	
	it(@"should update properties identified by keypaths when the binding was created when one of the two objects had an intermediate nil value", ^{
		RACBind(a, strongTestObjectValue.stringValue) = RACBind(b, strongTestObjectValue.stringValue);
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		c.stringValue = testName1;
		a.strongTestObjectValue = c;
		
		expect(a.strongTestObjectValue.stringValue).to.equal(testName1);
		expect(b.strongTestObjectValue.stringValue).to.equal(testName1);
		expect(a.strongTestObjectValue).notTo.equal(b.strongTestObjectValue);
	});
	
	it(@"should take the value of the object being bound to at the start", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;
		RACBind(a, stringValue) = RACBind(b, stringValue);
		expect(a.stringValue).to.equal(testName2);
		expect(b.stringValue).to.equal(testName2);
	});
	
	it(@"should update the value even if it's the same value the object had before it was bound", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;
		RACBind(a, stringValue) = RACBind(b, stringValue);
		expect(a.stringValue).to.equal(testName2);
		expect(b.stringValue).to.equal(testName2);
		
		b.stringValue = testName1;
		expect(a.stringValue).to.equal(testName1);
		expect(b.stringValue).to.equal(testName1);
	});
	
	it(@"should bind transitively", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;
		c.stringValue = testName3;
		RACBind(a, stringValue) = RACBind(b, stringValue);
		RACBind(b, stringValue) = RACBind(c, stringValue);
		expect(a.stringValue).to.equal(testName3);
		expect(b.stringValue).to.equal(testName3);
		expect(c.stringValue).to.equal(testName3);
		
		c.stringValue = testName1;
		expect(a.stringValue).to.equal(testName1);
		expect(b.stringValue).to.equal(testName1);
		expect(c.stringValue).to.equal(testName1);
		
		b.stringValue = testName2;
		expect(a.stringValue).to.equal(testName2);
		expect(b.stringValue).to.equal(testName2);
		expect(c.stringValue).to.equal(testName2);
		
		a.stringValue = testName3;
		expect(a.stringValue).to.equal(testName3);
		expect(b.stringValue).to.equal(testName3);
		expect(c.stringValue).to.equal(testName3);
	});
	
	it(@"should bind changes made by KVC on arrays", ^{
		b.arrayValue = @[];
		RACBind(a, arrayValue) = RACBind(b, arrayValue);
		[[b mutableArrayValueForKeyPath:@keypath(b.arrayValue)] addObject:@1];
		expect(a.arrayValue).to.equal(b.arrayValue);
	});
	
	it(@"should bind changes made by KVC on sets", ^{
		b.setValue = [NSSet set];
		RACBind(a, setValue) = RACBind(b, setValue);
		[[b mutableSetValueForKeyPath:@keypath(b.setValue)] addObject:@1];
		expect(a.setValue).to.equal(b.setValue);
	});
	
	it(@"should bind changes made by KVC on ordered sets", ^{
		b.orderedSetValue = [NSOrderedSet orderedSet];
		RACBind(a, orderedSetValue) = RACBind(b, orderedSetValue);
		[[b mutableOrderedSetValueForKeyPath:@keypath(b.orderedSetValue)] addObject:@1];
		expect(a.orderedSetValue).to.equal(b.orderedSetValue);
	});
	
	it(@"should handle deallocation of intermediate objects correctly even without support from KVO", ^{
		__block BOOL wasDisposed = NO;
		RACBind(a, weakTestObjectValue.stringValue) = RACBind(b, strongTestObjectValue.stringValue);
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		@autoreleasepool {
			RACTestObject *object = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];
			
			a.weakTestObjectValue = object;
			object.stringValue = testName1;
			
			expect(wasDisposed).to.beFalsy();
			
			expect(b.strongTestObjectValue.stringValue).to.equal(testName1);
		}
		
		expect(wasDisposed).will.beTruthy();
		expect(b.strongTestObjectValue.stringValue).to.beNil();
	});
	
	it(@"should stop binding when disposed", ^{
		RACBinding *aBinding = RACBind(a, stringValue);
		RACBinding *bBinding = RACBind(b, stringValue);
		RACDisposable *aDisposable = [bBinding subscribe:aBinding];
		RACDisposable *bDisposable = [aBinding subscribe:bBinding];

		a.stringValue = testName1;
		expect(a.stringValue).to.equal(testName1);
		expect(b.stringValue).to.equal(testName1);

		[aDisposable dispose];
		[bDisposable dispose];

		a.stringValue = testName2;
		expect(a.stringValue).to.equal(testName2);
		expect(b.stringValue).to.equal(testName1);
	});
});

SpecEnd
