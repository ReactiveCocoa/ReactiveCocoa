//
//  NSObjectRACLifting.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "RACTestObject.h"
#import "RACSubject.h"
#import "RACUnit.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"

// <RACLiftingTestRig> specifies the basic behavior necessary for testing
// different techniques of message lifting (namely -rac_lift and
// -liftSelect:withObjects:).
//
// The implementation of each method in this protocol should perform the
// corresponding lifted operation on its `target`.
@protocol RACLiftingTestRig <NSObject>
@property (weak) RACTestObject *target;
- (void)setObjectValue:(id)objectValue;
- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue;
- (RACSignal *)combineObjectValue:(id)objectValue andObjectValue:(id)secondObjectValue;
@optional
- (void)setIntegerValue:(id)integerValue;
- (void)setObjectValue:(id)objectValue andIntegerValue:(id)integerValue;
@end

@interface RACLiftingHOMTestRig : NSObject <RACLiftingTestRig>
@end

@interface RACLiftingSelectorTestRig : NSObject <RACLiftingTestRig>
@end

static NSString *const kRACLiftingTestRigClass = @"kRACLiftingTestRigClass";

SpecBegin(NSObjectRACLiftingSpec)

sharedExamplesFor(@"RACLifting", ^(NSDictionary *data) {
	__block RACTestObject *object;
	__block id<RACLiftingTestRig> testRig;

	beforeEach(^{
		object = [RACTestObject new];
		testRig = [data[kRACLiftingTestRigClass] new];
		testRig.target = object;
	});

	it(@"should call the selector with the value of the signal", ^{
		RACSubject *subject = [RACSubject subject];
		[testRig setObjectValue:subject];

		expect(object.objectValue).to.beNil();

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);

		[subject sendNext:@42];
		expect(object.objectValue).to.equal(@42);
	});

	it(@"should work with signals that immediately start with a value", ^{
		RACSubject *subject = [RACSubject subject];
		[testRig setObjectValue:[subject startWith:@42]];

		expect(object.objectValue).to.equal(@42);

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);
	});

	it(@"should call the selector with the value of the signal unboxed", ^{
		if (![testRig respondsToSelector:@selector(setIntegerValue:)]) return;

		RACSubject *subject = [RACSubject subject];
		[testRig setIntegerValue:subject];

		expect(object.integerValue).to.equal(0);

		[subject sendNext:@1];
		expect(object.integerValue).to.equal(1);

		[subject sendNext:@42];
		expect(object.integerValue).to.equal(42);
	});

	it(@"should work with multiple signal arguments {id, int}", ^{
		if (![testRig respondsToSelector:@selector(setObjectValue:andIntegerValue:)]) return;

		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *integerValueSubject = [RACSubject subject];
		[testRig setObjectValue:objectValueSubject andIntegerValue:integerValueSubject];

		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beFalsy();
		expect(object.objectValue).to.beNil();
		expect(object.integerValue).to.equal(0);

		[objectValueSubject sendNext:@1];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beFalsy();
		expect(object.objectValue).to.beNil();
		expect(object.integerValue).to.equal(0);

		[integerValueSubject sendNext:@42];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beTruthy();
		expect(object.objectValue).to.equal(@1);
		expect(object.integerValue).to.equal(42);
	});

	it(@"should work with multiple signal arguments {id, id}", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *objectValueSubject2 = [RACSubject subject];

		[testRig setObjectValue:objectValueSubject andSecondObjectValue:objectValueSubject2];

		expect(object.hasInvokedSetObjectValueAndSecondObjectValue).to.beFalsy();
		expect(object.objectValue).to.beNil();
		expect(object.secondObjectValue).to.beNil();

		[objectValueSubject sendNext:@1];
		expect(object.hasInvokedSetObjectValueAndSecondObjectValue).to.beFalsy();
		expect(object.objectValue).to.beNil();
		expect(object.secondObjectValue).to.beNil();

		[objectValueSubject2 sendNext:@42];
		expect(object.hasInvokedSetObjectValueAndSecondObjectValue).to.beTruthy();
		expect(object.objectValue).to.equal(@1);
		expect(object.secondObjectValue).to.equal(@42);
	});

	it(@"should immediately invoke the selector when it isn't given any signal arguments", ^{
		[testRig setObjectValue:@42];
		expect(object.objectValue).to.equal(@42);
	});

	it(@"should work with class objects", ^{
		RACSubject *subject = [RACSubject subject];
		[testRig setObjectValue:subject];

		expect(object.objectValue).to.equal(nil);

		[subject sendNext:self.class];
		expect(object.objectValue).to.equal(self.class);
	});

	it(@"should send the latest value of the signal as the right argument", ^{
		RACSubject *subject = [RACSubject subject];
		[testRig setObjectValue:@"object" andSecondObjectValue:subject];
		[subject sendNext:@1];

		expect(object.objectValue).to.equal(@"object");
		expect(object.secondObjectValue).to.equal(@1);
	});


	it(@"shouldn't strongly capture the receiver", ^{
		__block BOOL dealloced = NO;
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [RACTestObject new];
			[testObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				dealloced = YES;
			}]];

			testRig = [data[kRACLiftingTestRigClass] new];
			testRig.target = testObject;

			RACSubject *subject = [RACSubject subject];
			[testRig setObjectValue:subject];
			[subject sendNext:@1];
		}

		expect(dealloced).to.beTruthy();
	});

	describe(@"the returned signal", ^{
		it(@"should send the return value of the method invocation", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *objectSubject2 = [RACSubject subject];
			RACSignal *signal = [testRig combineObjectValue:objectSubject andObjectValue:objectSubject2];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[objectSubject sendNext:@"Magic number"];
			expect(result).to.beNil();

			[objectSubject2 sendNext:@42];
			expect(result).to.equal(@"Magic number: 42");
		});


		it(@"should replay the last value", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *objectSubject2 = [RACSubject subject];
			RACSignal *signal = [testRig combineObjectValue:objectSubject andObjectValue:objectSubject2];

			[objectSubject sendNext:@"Magic number"];
			[objectSubject2 sendNext:@42];
			[objectSubject2 sendNext:@43];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			expect(result).to.equal(@"Magic number: 43");
		});
	});
});

describe(@"-rac_liftSelector:withObjects:", ^{
	__block RACTestObject *object;

	beforeEach(^{
		object = [RACTestObject new];
	});

	itShouldBehaveLike(@"RACLifting", @{ kRACLiftingTestRigClass : RACLiftingSelectorTestRig.class });

	it(@"should work for char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setCharPointerValue:) withObjects:subject];

		expect(object.charPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.charPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for CGRect", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRectValue:) withObjects:subject];

		expect(object.rectValue).to.equal(CGRectZero);

		CGRect value = CGRectMake(10, 20, 30, 40);
		[subject sendNext:[NSValue valueWithRect:value]];
		expect(object.rectValue).to.equal(value);
	});

	it(@"should work for CGSize", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setSizeValue:) withObjects:subject];

		expect(object.sizeValue).to.equal(CGSizeZero);

		CGSize value = CGSizeMake(10, 20);
		[subject sendNext:[NSValue valueWithSize:value]];
		expect(object.sizeValue).to.equal(value);
	});

	it(@"should work for CGPoint", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setPointValue:) withObjects:subject];

		expect(object.pointValue).to.equal(CGPointZero);

		CGPoint value = CGPointMake(10, 20);
		[subject sendNext:[NSValue valueWithPoint:value]];
		expect(object.pointValue).to.equal(value);
	});

	describe(@"the returned signal", ^{
		it(@"should send RACUnit.defaultUnit for void-returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(setObjectValue:) withObjects:subject];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@1];

			expect(result).to.equal(RACUnit.defaultUnit);
		});
	});
});

describe(@"-rac_liftBlock:withObjects:", ^{
	it(@"should invoke the block with the latest value from the signals", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];

		__block id received1;
		__block id received2;
		RACSignal *signal = [self rac_liftBlock:^(NSNumber *arg1, NSNumber *arg2) {
			received1 = arg1;
			received2 = arg2;
			return @(arg1.unsignedIntegerValue + arg2.unsignedIntegerValue);
		} withArguments:subject1, subject2, nil];

		[subject1 sendNext:@1];
		expect(received1).to.beNil();
		expect(received2).to.beNil();

		[subject2 sendNext:@2];
		expect(received1).to.equal(@1);
		expect(received2).to.equal(@2);

		__block id received;
		[signal subscribeNext:^(id x) {
			received = x;
		}];

		expect(received).to.equal(@3);
	});

	it(@"should send the latest value of the signal as the right argument", ^{
		RACSubject *subject = [RACSubject subject];
		__block id received1;
		__block id received2;
		[self rac_liftBlock:^(id object1, id object2) {
			received1 = object1;
			received2 = object2;
			return nil;
		} withArguments:@"object", subject, nil];
		
		[subject sendNext:@1];

		expect(received1).to.equal(@"object");
		expect(received2).to.equal(1);
	});
});

describe(@"-rac_lift", ^{
	__block RACTestObject *object;

	beforeEach(^{
		object = [RACTestObject new];
	});

	itShouldBehaveLike(@"RACLifting", @{ kRACLiftingTestRigClass: RACLiftingHOMTestRig.class });

	it(@"should work with mixed signal / non-signal arguments", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		[object.rac_lift setObjectValue:objectValueSubject andIntegerValue:42];

		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beFalsy();
		expect(object.objectValue).to.beNil();
		expect(object.integerValue).to.equal(0);

		[objectValueSubject sendNext:@1];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beTruthy();
		expect(object.objectValue).to.equal(@1);
		expect(object.integerValue).to.equal(42);
	});
});

SpecEnd

@implementation RACLiftingHOMTestRig
@synthesize target = _target;

- (void)setObjectValue:(id)objectValue {
	_target.rac_lift.objectValue = objectValue;
}

- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	[_target.rac_lift setObjectValue:objectValue andSecondObjectValue:secondObjectValue];
}

- (RACSignal *)combineObjectValue:(id)objectValue andObjectValue:(id)secondObjectValue {
	return (id)[_target.rac_lift combineObjectValue:objectValue andSecondObjectValue:secondObjectValue];
}

@end

@implementation RACLiftingSelectorTestRig
@synthesize target = _target;

- (void)setObjectValue:(id)objectValue {
	[_target rac_liftSelector:@selector(setObjectValue:) withObjects:objectValue];
}

- (void)setIntegerValue:(id)integerValue {
	[_target rac_liftSelector:@selector(setIntegerValue:) withObjects:integerValue];
}

- (void)setObjectValue:(id)objectValue andIntegerValue:(id)integerValue {
	[_target rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withObjects:objectValue, integerValue];
}

- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	[_target rac_liftSelector:@selector(setObjectValue:andSecondObjectValue:) withObjects:objectValue, secondObjectValue];
}

- (RACSignal *)combineObjectValue:(id)objectValue andObjectValue:(id)secondObjectValue {
	return [_target rac_liftSelector:@selector(combineObjectValue:andSecondObjectValue:) withObjects:objectValue, secondObjectValue];
}

@end
