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

@protocol TestProtocol

@required
- (BOOL)requiredMethod:(NSUInteger)number;
- (void)lifeIsGood:(id)sender;

@optional
- (NSUInteger)optionalMethodWithObject:(id)object flag:(BOOL)flag;
- (id)objectValue;
- (RACTestSmallStruct)smallStructValue;
- (RACTestBigStruct)bigStructValue;
- (RACTestComplexFloatStruct)complexFloatStructValue;
- (RACTestComplexDoubleStruct)complexDoubleStructValue;

@end

SpecBegin(NSObjectRACSelectorSignal)

describe(@"RACTestObject", ^{
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

	it(@"should send arguments for invocation and invoke the original method on previously KVO'd receiver", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		[RACObserve(object, objectValue) replayLast];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(object.hasInvokedSetObjectValueAndSecondObjectValue).to.beTruthy();
		expect(object.objectValue).to.equal(@YES);
		expect(object.secondObjectValue).to.equal(@"Winner");

		expect(value).to.equal(@YES);
		expect(key).to.equal(@"Winner");
	});

	it(@"should send arguments for invocation and invoke the original method when receiver is subsequently KVO'd", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[RACObserve(object, objectValue) replayLast];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(object.hasInvokedSetObjectValueAndSecondObjectValue).to.beTruthy();
		expect(object.objectValue).to.equal(@YES);
		expect(object.secondObjectValue).to.equal(@"Winner");

		expect(value).to.equal(@YES);
		expect(key).to.equal(@"Winner");
	});

	it(@"should send non-object arguments", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id value;
		[[object rac_signalForSelector:@selector(setIntegerValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		object.integerValue = 42;
		expect(value).to.equal(@42);
	});

	it(@"should send on signal after the original method is invoked", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block BOOL invokedMethodBefore = NO;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			invokedMethodBefore = object.hasInvokedSetObjectValueAndSecondObjectValue;
		}];
		
		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];
		expect(invokedMethodBefore).to.beTruthy();
	});

	it(@"should send arguments of small struct return methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value = nil;
		[[object rac_signalForSelector:@selector(returnSmallStruct)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object returnSmallStruct];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should send arguments of big struct return methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value = nil;
		[[object rac_signalForSelector:@selector(returnBigStruct)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object returnBigStruct];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should send arguments of complex float struct return methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value = nil;
		[[object rac_signalForSelector:@selector(returnComplexFloatStruct)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object returnComplexFloatStruct];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should send arguments of complex double struct return methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value = nil;
		[[object rac_signalForSelector:@selector(returnComplexDoubleStruct)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object returnComplexDoubleStruct];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});
});

it(@"should swizzle an NSObject method", ^{
	NSObject *object = [[NSObject alloc] init];

	__block RACTuple *value;
	[[object rac_signalForSelector:@selector(description)] subscribeNext:^(RACTuple *x) {
		value = x;
	}];

	expect([object description]).notTo.beNil();
	expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
});

it(@"should work on a class that already overrides -forwardInvocation:", ^{
	RACSubclassObject *object = [[RACSubclassObject alloc] init];

	__block id value;
	[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
		value = x.first;
	}];

	[object lifeIsGood:@42];
	expect(value).to.equal(@42);

	expect(object.forwardedSelector).to.beNil();

	[object performSelector:@selector(allObjects)];

	expect(value).to.equal(@42);
	expect(object.forwardedSelector).to.equal(@selector(allObjects));
});

describe(@"two classes in the same hierarchy", ^{
	__block RACTestObject *superclassObj;
	__block RACTuple *superclassTuple;

	__block RACSubclassObject *subclassObj;
	__block RACTuple *subclassTuple;

	beforeEach(^{
		superclassObj = [[RACTestObject alloc] init];
		expect(superclassObj).notTo.beNil();

		subclassObj = [[RACSubclassObject alloc] init];
		expect(subclassObj).notTo.beNil();
	});

	it(@"should not collide", ^{
		[[superclassObj rac_signalForSelector:@selector(combineObjectValue:andIntegerValue:)] subscribeNext:^(RACTuple *t) {
			superclassTuple = t;
		}];

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

	it(@"should not collide when the superclass is invoked asynchronously", ^{
		[[superclassObj rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *t) {
			superclassTuple = t;
		}];

		[[subclassObj rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *t) {
			subclassTuple = t;
		}];

		[superclassObj setObjectValue:@"foo" andSecondObjectValue:@"42"];
		expect(superclassObj.hasInvokedSetObjectValueAndSecondObjectValue).to.beTruthy();

		NSArray *expectedValues = @[ @"foo", @"42" ];
		expect(superclassTuple.allObjects).to.equal(expectedValues);

		[subclassObj setObjectValue:@"foo" andSecondObjectValue:@"42"];
		expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue).to.beFalsy();
		expect(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue).will.beTruthy();

		expectedValues = @[ @"foo", @"42" ];
		expect(subclassTuple.allObjects).to.equal(expectedValues);
	});
});

describe(@"-rac_signalForSelector:fromProtocol", ^{
	__block RACTestObject<TestProtocol> *object;
	__block Protocol *protocol;
	
	beforeEach(^{
		object = (id)[[RACTestObject alloc] init];
		expect(object).notTo.beNil();

		protocol = @protocol(TestProtocol);
		expect(protocol).notTo.beNil();
	});

	it(@"should not clobber a required method already implemented", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[object lifeIsGood:@42];
		expect(value).to.equal(@42);
	});

	it(@"should not clobber an optional method already implemented", ^{
		object.objectValue = @"foo";

		__block id value;
		[[object rac_signalForSelector:@selector(objectValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		expect([object objectValue]).to.equal(@"foo");
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should inject a required method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(requiredMethod:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		expect([object requiredMethod:42]).to.beFalsy();
		expect(value).to.equal(42);
	});

	it(@"should inject an optional method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(optionalMethodWithObject:flag:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		expect([object optionalMethodWithObject:@"foo" flag:YES]).to.equal(0);
		expect(value).to.equal(RACTuplePack(@"foo", @YES));
	});

	it(@"should inject a small struct returning method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(smallStructValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object smallStructValue];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should inject a big struct returning method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(bigStructValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object bigStructValue];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should inject a complex float struct returning method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(complexFloatStructValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object complexFloatStructValue];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});

	it(@"should inject a complex double struct returning method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(complexDoubleStructValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		[object complexDoubleStructValue];
		expect(value).to.equal([RACTuple tupleWithObjectsFromArray:@[]]);
	});
});

SpecEnd
