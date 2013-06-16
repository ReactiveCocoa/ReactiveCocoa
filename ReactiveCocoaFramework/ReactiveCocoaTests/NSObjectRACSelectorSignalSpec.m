//
//  NSObjectRACSelectorSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"
#import "RACSubclassObject.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSignal.h"
#import "RACTuple.h"

SpecBegin(NSObjectRACSelectorSignal)

describe(@"with a RACTestObject instance method", ^{
	it(@"should send the argument for each invocation", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[object lifeIsGood:@42];

		expect(value).to.equal(@42);
	});

	it(@"should send completed on deallocation", ^{
		__block BOOL completed = NO;
		__block BOOL deallocated = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];

			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeCompleted:^{
				completed = YES;
			}];

			expect(deallocated).to.beFalsy();
			expect(completed).to.beFalsy();
		}

		expect(deallocated).to.beTruthy();
		expect(completed).to.beTruthy();
	});

	it(@"should send for a zero-argument method", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block RACTuple *value;
		[[object rac_signalForSelector:@selector(objectValue)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object objectValue];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should send the argument for each invocation to the instance's own signal", ^{
		RACTestObject *object1 = [[RACTestObject alloc] init];
		__block id value1;
		[[object1 rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value1 = x.first;
		}];

		RACTestObject *object2 = [[RACTestObject alloc] init];
		__block id value2;
		[[object2 rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value2 = x.first;
		}];

		[object1 lifeIsGood:@42];
		[object2 lifeIsGood:@"Carpe diem"];

		expect(value1).to.equal(@42);
		expect(value2).to.equal(@"Carpe diem");
	});

	it(@"should send multiple arguments for each invocation", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id value1;
		__block id value2;
		[[object rac_signalForSelector:@selector(combineObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value1 = x.first;
			value2 = x.second;
		}];

		expect([object combineObjectValue:@42 andSecondObjectValue:@"foo"]).to.equal(@"42: foo");
		expect(value1).to.equal(@42);
		expect(value2).to.equal(@"foo");
	});

	it(@"should send arguments for invocation of non-existant methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObject:forKey:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[object performSelector:@selector(setObject:forKey:) withObject:@YES withObject:@"Winner"];

		expect(value).to.equal(@YES);
		expect(key).to.equal(@"Winner");
	});

	it(@"should send arguments for invocation on previously KVO'd receiver", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		[RACAble(object, objectValue) replayLast];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(value).to.equal(@YES);
		expect(key).to.equal(@"Winner");
	});

	it(@"should send arguments for invocation when receiver is subsequently KVO'd", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[RACAble(object, objectValue) replayLast];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(value).to.equal(@YES);
		expect(key).to.equal(@"Winner");
	});
});

describe(@"with a RACTestObject class method", ^{
	it(@"should send the argument for each invocation", ^{
		__block id value;
		[[RACTestObject rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[RACTestObject lifeIsGood:@42];

		expect(value).to.equal(@42);
	});
});

it(@"should swizzle an NSObject instance method", ^{
	NSObject *object = [[NSObject alloc] init];

	__block RACTuple *value;
	[[object rac_signalForSelector:@selector(description)] subscribeNext:^(RACTuple *x) {
		value = x;
	}];

	expect([object description]).notTo.beNil();
	expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
});

it(@"should work for two classes in the same hierarchy", ^{
	RACTestObject *superclassObj = [[RACTestObject alloc] init];
	expect(superclassObj).notTo.beNil();

	__block RACTuple *superclassTuple;
	[[superclassObj rac_signalForSelector:@selector(combineObjectValue:andIntegerValue:)] subscribeNext:^(RACTuple *t) {
		superclassTuple = t;
	}];

	RACSubclassObject *subclassObj = [[RACSubclassObject alloc] init];
	expect(subclassObj).notTo.beNil();

	__block RACTuple *subclassTuple;
	[[subclassObj rac_signalForSelector:@selector(combineObjectValue:andIntegerValue:)] subscribeNext:^(RACTuple *t) {
		subclassTuple = t;
	}];

	expect([superclassObj combineObjectValue:@"foo" andIntegerValue:42]).to.equal(@"foo: 42");

	NSArray *expectedValues = @[ @"foo", @42 ];
	expect(superclassTuple.allObjects).to.equal(expectedValues);

	expect([subclassObj combineObjectValue:@"foo" andIntegerValue:42]).to.equal(@"fooSUBCLASS: 42");

	expectedValues = @[ @"foo", @42 ];
	expect(subclassTuple.allObjects).to.equal(expectedValues);
});

SpecEnd
