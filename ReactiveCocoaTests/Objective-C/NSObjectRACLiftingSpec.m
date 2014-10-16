//
//  NSObjectRACLifting.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"

#import "NSObject+RACLifting.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"
#import "RACTuple.h"
#import "RACUnit.h"

QuickSpecBegin(NSObjectRACLiftingSpec)

qck_describe(@"-rac_liftSelector:withSignals:", ^{
	__block RACTestObject *object;

	qck_beforeEach(^{
		object = [[RACTestObject alloc] init];
	});

	qck_it(@"should call the selector with the value of the signal", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withSignals:subject, nil];

		expect(object.objectValue).to(beNil());

		[subject sendNext:@1];
		expect(object.objectValue).to(equal(@1));

		[subject sendNext:@42];
		expect(object.objectValue).to(equal(@42));
	});
});

qck_describe(@"-rac_liftSelector:withSignalsFromArray:", ^{
	__block RACTestObject *object;

	qck_beforeEach(^{
		object = [[RACTestObject alloc] init];
	});

	qck_it(@"should call the selector with the value of the signal", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ subject ]];

		expect(object.objectValue).to(beNil());

		[subject sendNext:@1];
		expect(object.objectValue).to(equal(@1));

		[subject sendNext:@42];
		expect(object.objectValue).to(equal(@42));
	});

	qck_it(@"should call the selector with the value of the signal unboxed", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setIntegerValue:) withSignalsFromArray:@[ subject ]];

		expect(@(object.integerValue)).to(equal(@0));

		[subject sendNext:@1];
		expect(@(object.integerValue)).to(equal(@1));

		[subject sendNext:@42];
		expect(@(object.integerValue)).to(equal(@42));
	});

	qck_it(@"should work with multiple arguments", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *integerValueSubject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withSignalsFromArray:@[ objectValueSubject, integerValueSubject ]];

		expect(@(object.hasInvokedSetObjectValueAndIntegerValue)).to(beFalsy());
		expect(object.objectValue).to(beNil());
		expect(@(object.integerValue)).to(equal(@0));

		[objectValueSubject sendNext:@1];
		expect(@(object.hasInvokedSetObjectValueAndIntegerValue)).to(beFalsy());
		expect(object.objectValue).to(beNil());
		expect(@(object.integerValue)).to(equal(@0));

		[integerValueSubject sendNext:@42];
		expect(@(object.hasInvokedSetObjectValueAndIntegerValue)).to(beTruthy());
		expect(object.objectValue).to(equal(@1));
		expect(@(object.integerValue)).to(equal(@42));
	});

	qck_it(@"should work with signals that immediately start with a value", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ [subject startWith:@42] ]];

		expect(object.objectValue).to(equal(@42));

		[subject sendNext:@1];
		expect(object.objectValue).to(equal(@1));
	});

	qck_it(@"should work with signals that send nil", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ subject ]];

		[subject sendNext:nil];
		expect(object.objectValue).to(beNil());

		[subject sendNext:RACTupleNil.tupleNil];
		expect(object.objectValue).to(beNil());
	});

	qck_it(@"should work with integers", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setIntegerValue:) withSignalsFromArray:@[ subject ]];

		expect(@(object.integerValue)).to(equal(@0));

		[subject sendNext:@1];
		expect(@(object.integerValue)).to(equal(@1));
	});

	qck_it(@"should convert between numeric types", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setIntegerValue:) withSignalsFromArray:@[ subject ]];

		expect(@(object.integerValue)).to(equal(@0));

		[subject sendNext:@1.0];
		expect(@(object.integerValue)).to(equal(@1));
	});

	qck_it(@"should work with class objects", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ subject ]];

		expect(object.objectValue).to(beNil());

		[subject sendNext:self.class];
		expect(object.objectValue).to(equal(self.class));
	});

	qck_it(@"should work for char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setCharPointerValue:) withSignalsFromArray:@[ subject ]];

		expect([NSValue valueWithPointer:object.charPointerValue]).to(equal([NSValue valueWithPointer:NULL]));

		NSString *string = @"blah blah blah";
		[subject sendNext:string];
		expect(@(object.charPointerValue)).to(equal(string));
	});

	qck_it(@"should work for const char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setConstCharPointerValue:) withSignalsFromArray:@[ subject ]];

		expect([NSValue valueWithPointer:object.constCharPointerValue]).to(equal([NSValue valueWithPointer:NULL]));

		NSString *string = @"blah blah blah";
		[subject sendNext:string];
		expect(@(object.constCharPointerValue)).to(equal(string));
	});

	qck_it(@"should work for CGRect", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRectValue:) withSignalsFromArray:@[ subject ]];

		expect(@(CGRectEqualToRect(object.rectValue, CGRectZero))).to(beTruthy());

		CGRect value = CGRectMake(10, 20, 30, 40);
		[subject sendNext:[NSValue valueWithBytes:&value objCType:@encode(CGRect)]];
		expect(@(CGRectEqualToRect(object.rectValue, value))).to(beTruthy());
	});

	qck_it(@"should work for CGSize", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setSizeValue:) withSignalsFromArray:@[ subject ]];

		expect(@(CGSizeEqualToSize(object.sizeValue, CGSizeZero))).to(beTruthy());

		CGSize value = CGSizeMake(10, 20);
		[subject sendNext:[NSValue valueWithBytes:&value objCType:@encode(CGSize)]];
		expect(@(CGSizeEqualToSize(object.sizeValue, value))).to(beTruthy());
	});

	qck_it(@"should work for CGPoint", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setPointValue:) withSignalsFromArray:@[ subject ]];

		expect(@(CGPointEqualToPoint(object.pointValue, CGPointZero))).to(beTruthy());

		CGPoint value = CGPointMake(10, 20);
		[subject sendNext:[NSValue valueWithBytes:&value objCType:@encode(CGPoint)]];
		expect(@(CGPointEqualToPoint(object.pointValue, value))).to(beTruthy());
	});

	qck_it(@"should work for NSRange", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setRangeValue:) withSignalsFromArray:@[ subject ]];

		expect(@(NSEqualRanges(object.rangeValue, NSMakeRange(0, 0)))).to(beTruthy());

		NSRange value = NSMakeRange(10, 20);
		[subject sendNext:[NSValue valueWithRange:value]];
		expect(@(NSEqualRanges(object.rangeValue, value))).to(beTruthy());
	});

	qck_it(@"should work for _Bool", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setC99BoolValue:) withSignalsFromArray:@[ subject ]];

		expect(@(object.c99BoolValue)).to(beFalsy());

		_Bool value = true;
		[subject sendNext:@(value)];
		expect(@(object.c99BoolValue)).to(beTruthy());
	});

	qck_it(@"should work for primitive pointers", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(write5ToIntPointer:) withSignalsFromArray:@[ subject ]];

		int value = 0;
		int *valuePointer = &value;
		expect(@(value)).to(equal(@0));

		[subject sendNext:[NSValue valueWithPointer:valuePointer]];
		expect(@(value)).to(equal(@5));
	});

	qck_it(@"should work for custom structs", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setStructValue:) withSignalsFromArray:@[ subject ]];

		expect(@(object.structValue.integerField)).to(equal(@0));
		expect(@(object.structValue.doubleField)).to(equal(@0.0));

		RACTestStruct value = (RACTestStruct){7, 1.23};
		[subject sendNext:[NSValue valueWithBytes:&value objCType:@encode(typeof(value))]];
		expect(@(object.structValue.integerField)).to(equal(@(value.integerField)));
		expect(@(object.structValue.doubleField)).to(equal(@(value.doubleField)));
	});

	qck_it(@"should send the latest value of the signal as the right argument", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withSignalsFromArray:@[ [RACSignal return:@"object"], subject ]];
		[subject sendNext:@1];

		expect(object.objectValue).to(equal(@"object"));
		expect(@(object.integerValue)).to(equal(@1));
	});

	qck_describe(@"the returned signal", ^{
		qck_it(@"should send the return value of the method invocation", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withSignalsFromArray:@[ objectSubject, integerSubject ]];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[objectSubject sendNext:@"Magic number"];
			expect(result).to(beNil());

			[integerSubject sendNext:@42];
			expect(result).to(equal(@"Magic number: 42"));
		});

		qck_it(@"should send RACUnit.defaultUnit for void-returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ subject ]];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@1];

			expect(result).to(equal(RACUnit.defaultUnit));
		});

		qck_it(@"should support integer returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(doubleInteger:) withSignalsFromArray:@[ subject ]];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@1];

			expect(result).to(equal(@2));
		});

		qck_it(@"should support char * returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(doubleString:) withSignalsFromArray:@[ subject ]];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@"test"];

			expect(result).to(equal(@"testtest"));
		});

		qck_it(@"should support const char * returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(doubleConstString:) withSignalsFromArray:@[ subject ]];

			__block id result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:@"test"];

			expect(result).to(equal(@"testtest"));
		});

		qck_it(@"should support struct returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(doubleStruct:) withSignalsFromArray:@[ subject ]];

			__block NSValue *boxedResult;
			[signal subscribeNext:^(id x) {
				boxedResult = x;
			}];

			RACTestStruct value = {4, 12.3};
			NSValue *boxedValue = [NSValue valueWithBytes:&value objCType:@encode(typeof(value))];
			[subject sendNext:boxedValue];

			RACTestStruct result = {0, 0.0};
			[boxedResult getValue:&result];
			expect(@(result.integerField)).to(equal(@8));
			expect(@(result.doubleField)).to(equal(@24.6));
		});

		qck_it(@"should support block arguments and returns", ^{
			RACSubject *subject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(wrapBlock:) withSignalsFromArray:@[ subject ]];

			__block BOOL blockInvoked = NO;
			dispatch_block_t testBlock = ^{
				blockInvoked = YES;
			};

			__block dispatch_block_t result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			[subject sendNext:testBlock];
			expect(result).notTo(beNil());

			result();
			expect(@(blockInvoked)).to(beTruthy());
		});

		qck_it(@"should replay the last value", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSignal *signal = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withSignalsFromArray:@[ objectSubject, integerSubject ]];

			[objectSubject sendNext:@"Magic number"];
			[integerSubject sendNext:@42];
			[integerSubject sendNext:@43];

			__block NSString *result;
			[signal subscribeNext:^(id x) {
				result = x;
			}];

			expect(result).to(equal(@"Magic number: 43"));
		});
	});

	qck_it(@"shouldn't strongly capture the receiver", ^{
		__block BOOL dealloced = NO;
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[testObject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				dealloced = YES;
			}]];

			RACSubject *subject = [RACSubject subject];
			[testObject rac_liftSelector:@selector(setObjectValue:) withSignalsFromArray:@[ subject ]];
			[subject sendNext:@1];
		}

		expect(@(dealloced)).to(beTruthy());
	});
});

QuickSpecEnd
