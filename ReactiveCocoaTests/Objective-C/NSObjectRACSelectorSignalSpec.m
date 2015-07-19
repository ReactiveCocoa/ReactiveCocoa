//
//  NSObjectRACSelectorSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"
#import "RACSubclassObject.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACMulticastConnection.h"
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

@end

QuickSpecBegin(NSObjectRACSelectorSignalSpec)

qck_describe(@"RACTestObject", ^{
	qck_it(@"should send the argument for each invocation", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[object lifeIsGood:@42];

		expect(value).to(equal(@42));
	});

	qck_it(@"should send completed on deallocation", ^{
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

			expect(@(deallocated)).to(beFalsy());
			expect(@(completed)).to(beFalsy());
		}

		expect(@(deallocated)).to(beTruthy());
		expect(@(completed)).to(beTruthy());
	});

	qck_it(@"should send for a zero-argument method", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block RACTuple *value;
		[[object rac_signalForSelector:@selector(objectValue)] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		(void)[object objectValue];
		expect(value).to(equal([RACTuple tupleWithObjectsFromArray:@[]]));
	});

	qck_it(@"should send the argument for each invocation to the instance's own signal", ^{
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

		expect(value1).to(equal(@42));
		expect(value2).to(equal(@"Carpe diem"));
	});

	qck_it(@"should send multiple arguments for each invocation", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id value1;
		__block id value2;
		[[object rac_signalForSelector:@selector(combineObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value1 = x.first;
			value2 = x.second;
		}];

		expect([object combineObjectValue:@42 andSecondObjectValue:@"foo"]).to(equal(@"42: foo"));
		expect(value1).to(equal(@42));
		expect(value2).to(equal(@"foo"));
	});

	qck_it(@"should send arguments for invocation of non-existant methods", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObject:forKey:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[object performSelector:@selector(setObject:forKey:) withObject:@YES withObject:@"Winner"];

		expect(value).to(equal(@YES));
		expect(key).to(equal(@"Winner"));
	});

	qck_it(@"should send arguments for invocation and invoke the original method on previously KVO'd receiver", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		[[RACObserve(object, objectValue) publish] connect];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(@(object.hasInvokedSetObjectValueAndSecondObjectValue)).to(beTruthy());
		expect(object.objectValue).to(equal(@YES));
		expect(object.secondObjectValue).to(equal(@"Winner"));

		expect(value).to(equal(@YES));
		expect(key).to(equal(@"Winner"));
	});

	qck_it(@"should send arguments for invocation and invoke the original method when receiver is subsequently KVO'd", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id key;
		__block id value;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
			key = x.second;
		}];

		[[RACObserve(object, objectValue) publish] connect];

		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];

		expect(@(object.hasInvokedSetObjectValueAndSecondObjectValue)).to(beTruthy());
		expect(object.objectValue).to(equal(@YES));
		expect(object.secondObjectValue).to(equal(@"Winner"));

		expect(value).to(equal(@YES));
		expect(key).to(equal(@"Winner"));
	});

	qck_it(@"should properly implement -respondsToSelector: when called on KVO'd receiver", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		// First, setup KVO on `object`, which gives us the desired side-effect
		// of `object` taking on a KVO-custom subclass.
		[[RACObserve(object, objectValue) publish] connect];

		SEL selector = NSSelectorFromString(@"anyOldSelector:");

		// With the KVO subclass in place, call -rac_signalForSelector: to
		// implement -anyOldSelector: directly on the KVO subclass.
		[object rac_signalForSelector:selector];

		expect(@([object respondsToSelector:selector])).to(beTruthy());
	});

	qck_it(@"should properly implement -respondsToSelector: when called on signalForSelector'd receiver that has subsequently been KVO'd", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		SEL selector = NSSelectorFromString(@"anyOldSelector:");

		// Implement -anyOldSelector: on the object first
		[object rac_signalForSelector:selector];

		expect(@([object respondsToSelector:selector])).to(beTruthy());

		// Then KVO the object
		[[RACObserve(object, objectValue) publish] connect];

		expect(@([object respondsToSelector:selector])).to(beTruthy());
	});

	qck_it(@"should properly implement -respondsToSelector: when called on signalForSelector'd receiver that has subsequently been KVO'd, then signalForSelector'd again", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		SEL selector = NSSelectorFromString(@"anyOldSelector:");

		// Implement -anyOldSelector: on the object first
		[object rac_signalForSelector:selector];

		expect(@([object respondsToSelector:selector])).to(beTruthy());

		// Then KVO the object
		[[RACObserve(object, objectValue) publish] connect];

		expect(@([object respondsToSelector:selector])).to(beTruthy());
		
		SEL selector2 = NSSelectorFromString(@"anotherSelector:");

		// Then implement -anotherSelector: on the object
		[object rac_signalForSelector:selector2];

		expect(@([object respondsToSelector:selector2])).to(beTruthy());
	});
	
	qck_it(@"should call the right signal for two instances of the same class, adding signals for the same selector", ^{
		RACTestObject *object1 = [[RACTestObject alloc] init];
		RACTestObject *object2 = [[RACTestObject alloc] init];

		SEL selector = NSSelectorFromString(@"lifeIsGood:");

		__block id value1 = nil;
		[[object1 rac_signalForSelector:selector] subscribeNext:^(RACTuple *x) {
			value1 = x.first;
		}];

		__block id value2 = nil;
		[[object2 rac_signalForSelector:selector] subscribeNext:^(RACTuple *x) {
			value2 = x.first;
		}];

		[object1 lifeIsGood:@42];
		expect(value1).to(equal(@42));
		expect(value2).to(beNil());

		[object2 lifeIsGood:@420];
		expect(value1).to(equal(@42));
		expect(value2).to(equal(@420));
	});

	qck_it(@"should properly implement -respondsToSelector: for optional method from a protocol", ^{
		// Selector for the targeted optional method from a protocol.
		SEL selector = @selector(optionalProtocolMethodWithObjectValue:);

		RACTestObject *object1 = [[RACTestObject alloc] init];

		// Method implementation of the selector is added to its swizzled class.
		[object1 rac_signalForSelector:selector fromProtocol:@protocol(RACTestProtocol)];

		expect(@([object1 respondsToSelector:selector])).to(beTruthy());

		RACTestObject *object2 = [[RACTestObject alloc] init];

		// Call -rac_signalForSelector: to swizzle this instance's class,
		// method implementations of -respondsToSelector: and
		// -forwardInvocation:.
		[object2 rac_signalForSelector:@selector(lifeIsGood:)];

		// This instance should not respond to the selector because of not
		// calling -rac_signalForSelector: with the selector.
		expect(@([object2 respondsToSelector:selector])).to(beFalsy());
	});

	qck_it(@"should send non-object arguments", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block id value;
		[[object rac_signalForSelector:@selector(setIntegerValue:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		object.integerValue = 42;
		expect(value).to(equal(@42));
	});

	qck_it(@"should send on signal after the original method is invoked", ^{
		RACTestObject *object = [[RACTestObject alloc] init];

		__block BOOL invokedMethodBefore = NO;
		[[object rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *x) {
			invokedMethodBefore = object.hasInvokedSetObjectValueAndSecondObjectValue;
		}];
		
		[object setObjectValue:@YES andSecondObjectValue:@"Winner"];
		expect(@(invokedMethodBefore)).to(beTruthy());
	});
});

qck_it(@"should swizzle an NSObject method", ^{
	NSObject *object = [[NSObject alloc] init];

	__block RACTuple *value;
	[[object rac_signalForSelector:@selector(description)] subscribeNext:^(RACTuple *x) {
		value = x;
	}];

	expect([object description]).notTo(beNil());
	expect(value).to(equal([RACTuple tupleWithObjectsFromArray:@[]]));
});

qck_describe(@"a class that already overrides -forwardInvocation:", ^{
	qck_it(@"should invoke the superclass' implementation", ^{
		RACSubclassObject *object = [[RACSubclassObject alloc] init];

		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[object lifeIsGood:@42];
		expect(value).to(equal(@42));

		expect([NSValue valueWithPointer:object.forwardedSelector]).to(equal([NSValue valueWithPointer:NULL]));

		[object performSelector:@selector(allObjects)];

		expect(value).to(equal(@42));
		expect(NSStringFromSelector(object.forwardedSelector)).to(equal(@"allObjects"));
	});

	qck_it(@"should not infinite recurse when KVO'd after RAC swizzled", ^{
		RACSubclassObject *object = [[RACSubclassObject alloc] init];

		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[[RACObserve(object, objectValue) publish] connect];

		[object lifeIsGood:@42];
		expect(value).to(equal(@42));

		expect([NSValue valueWithPointer:object.forwardedSelector]).to(equal([NSValue valueWithPointer:NULL]));
		[object performSelector:@selector(allObjects)];
		expect(NSStringFromSelector(object.forwardedSelector)).to(equal(@"allObjects"));
	});
});

qck_describe(@"two classes in the same hierarchy", ^{
	__block RACTestObject *superclassObj;
	__block RACTuple *superclassTuple;

	__block RACSubclassObject *subclassObj;
	__block RACTuple *subclassTuple;

	qck_beforeEach(^{
		superclassObj = [[RACTestObject alloc] init];
		expect(superclassObj).notTo(beNil());

		subclassObj = [[RACSubclassObject alloc] init];
		expect(subclassObj).notTo(beNil());
	});

	qck_it(@"should not collide", ^{
		[[superclassObj rac_signalForSelector:@selector(combineObjectValue:andIntegerValue:)] subscribeNext:^(RACTuple *t) {
			superclassTuple = t;
		}];

		[[subclassObj rac_signalForSelector:@selector(combineObjectValue:andIntegerValue:)] subscribeNext:^(RACTuple *t) {
			subclassTuple = t;
		}];

		expect([superclassObj combineObjectValue:@"foo" andIntegerValue:42]).to(equal(@"foo: 42"));

		NSArray *expectedValues = @[ @"foo", @42 ];
		expect(superclassTuple.allObjects).to(equal(expectedValues));

		expect([subclassObj combineObjectValue:@"foo" andIntegerValue:42]).to(equal(@"fooSUBCLASS: 42"));

		expectedValues = @[ @"foo", @42 ];
		expect(subclassTuple.allObjects).to(equal(expectedValues));
	});

	qck_it(@"should not collide when the superclass is invoked asynchronously", ^{
		[[superclassObj rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *t) {
			superclassTuple = t;
		}];

		[[subclassObj rac_signalForSelector:@selector(setObjectValue:andSecondObjectValue:)] subscribeNext:^(RACTuple *t) {
			subclassTuple = t;
		}];

		[superclassObj setObjectValue:@"foo" andSecondObjectValue:@"42"];
		expect(@(superclassObj.hasInvokedSetObjectValueAndSecondObjectValue)).to(beTruthy());

		NSArray *expectedValues = @[ @"foo", @"42" ];
		expect(superclassTuple.allObjects).to(equal(expectedValues));

		[subclassObj setObjectValue:@"foo" andSecondObjectValue:@"42"];
		expect(@(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue)).to(beFalsy());
		expect(@(subclassObj.hasInvokedSetObjectValueAndSecondObjectValue)).toEventually(beTruthy());

		expectedValues = @[ @"foo", @"42" ];
		expect(subclassTuple.allObjects).to(equal(expectedValues));
	});
});

qck_describe(@"-rac_signalForSelector:fromProtocol", ^{
	__block RACTestObject<TestProtocol> *object;
	__block Protocol *protocol;
	
	qck_beforeEach(^{
		object = (id)[[RACTestObject alloc] init];
		expect(object).notTo(beNil());

		protocol = @protocol(TestProtocol);
		expect(protocol).notTo(beNil());
	});

	qck_it(@"should not clobber a required method already implemented", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		[object lifeIsGood:@42];
		expect(value).to(equal(@42));
	});

	qck_it(@"should not clobber an optional method already implemented", ^{
		object.objectValue = @"foo";

		__block id value;
		[[object rac_signalForSelector:@selector(objectValue) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		expect([object objectValue]).to(equal(@"foo"));
		expect(value).to(equal([RACTuple tupleWithObjectsFromArray:@[]]));
	});

	qck_it(@"should inject a required method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(requiredMethod:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x.first;
		}];

		expect(@([object requiredMethod:42])).to(beFalsy());
		expect(value).to(equal(@42));
	});

	qck_it(@"should inject an optional method", ^{
		__block id value;
		[[object rac_signalForSelector:@selector(optionalMethodWithObject:flag:) fromProtocol:protocol] subscribeNext:^(RACTuple *x) {
			value = x;
		}];

		expect(@([object optionalMethodWithObject:@"foo" flag:YES])).to(equal(@0));
		expect(value).to(equal(RACTuplePack(@"foo", @YES)));
	});
});

qck_describe(@"class reporting", ^{
	__block RACTestObject *object;
	__block Class originalClass;

	qck_beforeEach(^{
		object = [[RACTestObject alloc] init];
		originalClass = object.class;
	});

	qck_it(@"should report the original class", ^{
		[object rac_signalForSelector:@selector(lifeIsGood:)];
		expect(object.class).to(beIdenticalTo(originalClass));
	});

	qck_it(@"should report the original class when it's KVO'd after dynamically subclassing", ^{
		[object rac_signalForSelector:@selector(lifeIsGood:)];
		[[RACObserve(object, objectValue) publish] connect];
		expect(object.class).to(beIdenticalTo(originalClass));
	});

	qck_it(@"should report the original class when it's KVO'd before dynamically subclassing", ^{
		[[RACObserve(object, objectValue) publish] connect];
		[object rac_signalForSelector:@selector(lifeIsGood:)];
		expect(object.class).to(beIdenticalTo(originalClass));
	});
});

QuickSpecEnd
