//
//  NSObjectRACLifting.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "NSObjectRACLiftingExamples.h"
#import "RACTestObject.h"
#import "RACSubject.h"
#import "RACUnit.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACTuple.h"

SpecBegin(NSObjectRACLiftingSpec)

describe(@"-rac_liftSelector:withObjects:", ^{
	__block RACTestObject *object;

	beforeEach(^{
		object = [RACTestObject new];
	});

	itShouldBehaveLike(@"RACLifting", @{ RACLiftingTestRigName : RACLiftingSelectorTestRigName });

	it(@"should work for char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setCharPointerValue:) withObjects:subject];

		expect(object.charPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.charPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for const char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setConstCharPointerValue:) withObjects:subject];

		expect(object.constCharPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.constCharPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for NSRange", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRangeValue:) withObjects:subject];

		expect(NSEqualRanges(object.rangeValue, NSMakeRange(0, 0))).to.beTruthy();

		NSRange value = NSMakeRange(10, 20);
		[subject sendNext:[NSValue valueWithRange:value]];
		expect(NSEqualRanges(object.rangeValue, value)).to.beTruthy();
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

		it(@"should send boxed NSRange", ^{
			RACSubject *subject = [RACSubject subject];
			RACSubject *subject2 = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(returnRangeValueWithObjectValue:andIntegerValue:) withObjects:subject, subject2];

			__block NSValue *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@1];
			expect(result).to.beNil();

			[subject2 sendNext:@42];
			expect(@(result.objCType)).to.equal(@(@encode(NSRange)));
			expect(NSEqualRanges(result.rangeValue, NSMakeRange(1, 42))).to.beTruthy();
		});
	});
});

describe(@"-rac_liftSelector:withObjectsFromArray:", ^{
	__block RACTestObject *object;

	beforeEach(^{
		object = [[RACTestObject alloc] init];
	});

	it(@"should call the selector with the value of the signal", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ subject ]];

		expect(object.objectValue).to.beNil();

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);

		[subject sendNext:@42];
		expect(object.objectValue).to.equal(@42);
	});

	it(@"should call the selector with the value of the signal unboxed", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setIntegerValue:) withObjectsFromArray:@[ subject ]];

		expect(object.integerValue).to.equal(0);

		[subject sendNext:@1];
		expect(object.integerValue).to.equal(1);

		[subject sendNext:@42];
		expect(object.integerValue).to.equal(42);
	});

	it(@"should work with multiple arguments", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *integerValueSubject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withObjectsFromArray:@[ objectValueSubject, integerValueSubject ]];

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

	it(@"should work with signals that immediately start with a value", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ [subject startWith:@42] ]];

		expect(object.objectValue).to.equal(@42);

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);
	});

	it(@"should immediately invoke the selector when it isn't given any signal arguments", ^{
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ @42 ]];

		expect(object.objectValue).to.equal(@42);
	});

	it(@"should work with nil tuple arguments", ^{
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ RACTupleNil.tupleNil ]];

		expect(object.objectValue).to.equal(nil);
	});

	it(@"should work with signals that send nil", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ subject ]];

		[subject sendNext:nil];
		expect(object.objectValue).to.equal(nil);

		[subject sendNext:RACTupleNil.tupleNil];
		expect(object.objectValue).to.equal(nil);
	});

	it(@"should work with class objects", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ subject ]];

		expect(object.objectValue).to.equal(nil);

		[subject sendNext:self.class];
		expect(object.objectValue).to.equal(self.class);
	});

	it(@"should work for char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setCharPointerValue:) withObjectsFromArray:@[ subject ]];

		expect(object.charPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.charPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for const char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setConstCharPointerValue:) withObjectsFromArray:@[ subject ]];

		expect(object.constCharPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.constCharPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for NSRange", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRangeValue:) withObjectsFromArray:@[ subject ]];

		expect(NSEqualRanges(object.rangeValue, NSMakeRange(0, 0))).to.beTruthy();

		NSRange value = NSMakeRange(10, 20);
		[subject sendNext:[NSValue valueWithRange:value]];
		expect(NSEqualRanges(object.rangeValue, value)).to.beTruthy();
	});

	it(@"should send the latest value of the signal as the right argument", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withObjectsFromArray:@[ @"object", subject ]];
		[subject sendNext:@1];

		expect(object.objectValue).to.equal(@"object");
		expect(object.integerValue).to.equal(1);
	});

	describe(@"the returned signal", ^{
		it(@"should send the return value of the method invocation", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withObjectsFromArray:@[ objectSubject, integerSubject ]];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[objectSubject sendNext:@"Magic number"];
			expect(result).to.beNil();

			[integerSubject sendNext:@42];
			expect(result).to.equal(@"Magic number: 42");
		});

		it(@"should send RACUnit.defaultUnit for void-returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ subject ]];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@1];

			expect(result).to.equal(RACUnit.defaultUnit);
		});

		it(@"should replay the last value", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withObjectsFromArray:@[ objectSubject, integerSubject ]];

			[objectSubject sendNext:@"Magic number"];
			[integerSubject sendNext:@42];
			[integerSubject sendNext:@43];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			expect(result).to.equal(@"Magic number: 43");
		});
	});

	it(@"shouldn't strongly capture the receiver", ^{
		__block BOOL dealloced = NO;
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[testObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				dealloced = YES;
			}]];

			RACSubject *subject = [RACSubject subject];
			[testObject rac_liftSelector:@selector(setObjectValue:) withObjectsFromArray:@[ subject ]];
			[subject sendNext:@1];
		}

		expect(dealloced).to.beTruthy();
	});
});

describe(@"-rac_liftBlock:withArguments:", ^{
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

describe(@"-rac_liftBlock:withArgumentsFromArray:", ^{
	it(@"should invoke the block with the latest value from the signals", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];

		__block id received1;
		__block id received2;
		RACSignal *signal = [self rac_liftBlock:^(NSNumber *arg1, NSNumber *arg2) {
			received1 = arg1;
			received2 = arg2;
			return @(arg1.unsignedIntegerValue + arg2.unsignedIntegerValue);
		} withArgumentsFromArray:@[ subject1, subject2 ]];

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
		} withArgumentsFromArray:@[ @"object", subject ]];

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

	itShouldBehaveLike(@"RACLifting", @{ RACLiftingTestRigName: RACLiftingHOMTestRigName });

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
