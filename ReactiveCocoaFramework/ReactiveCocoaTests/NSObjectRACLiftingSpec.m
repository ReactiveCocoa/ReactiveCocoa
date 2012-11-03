//
//  NSObjectRACLifting.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSObject+RACLifting.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(NSObjectRACLiftingSpec)

describe(@"-rac_liftSelector:withObjects:", ^{
	__block RACTestObject *object;

	beforeEach(^{
		object = [[RACTestObject alloc] init];
	});

	it(@"should call the selector with the value of the subscribable", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:subject];

		expect(object.objectValue).to.beNil();

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);

		[subject sendNext:@42];
		expect(object.objectValue).to.equal(@42);
	});

	it(@"should call the selector with the value of the subscribable unboxed", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setIntegerValue:) withObjects:subject];

		expect(object.integerValue).to.equal(0);

		[subject sendNext:@1];
		expect(object.integerValue).to.equal(1);

		[subject sendNext:@42];
		expect(object.integerValue).to.equal(42);
	});

	it(@"should work with multiple arguments", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *integerValueSubject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withObjects:objectValueSubject, integerValueSubject];

		expect(object.objectValue).to.beNil();
		expect(object.integerValue).to.equal(0);

		[objectValueSubject sendNext:@1];
		expect(object.objectValue).to.beNil();
		expect(object.integerValue).to.equal(0);

		[integerValueSubject sendNext:@42];
		expect(object.objectValue).to.equal(@1);
		expect(object.integerValue).to.equal(42);
	});

	it(@"should only call the selector once all subscribables have yielded a value", ^{
		RACSubject *objectValueSubject = [RACSubject subject];
		RACSubject *integerValueSubject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:andIntegerValue:) withObjects:objectValueSubject, integerValueSubject];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beFalsy();

		[objectValueSubject sendNext:@1];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beFalsy();

		[integerValueSubject sendNext:@42];
		expect(object.hasInvokedSetObjectValueAndIntegerValue).to.beTruthy();
	});

	it(@"should work with subscribables that immediately start with a value", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:[subject startWith:@42]];

		expect(object.objectValue).to.equal(@42);

		[subject sendNext:@1];
		expect(object.objectValue).to.equal(@1);
	});

	it(@"shouldn't do anything when it isn't given any subscribable arguments", ^{
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:@42];

		expect(object.objectValue).to.beNil();
	});

	it(@"should work with class objects", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:subject];

		expect(object.objectValue).to.equal(nil);

		[subject sendNext:self.class];
		expect(object.objectValue).to.equal(self.class);
	});

	it(@"should work for char pointer", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setCharPointerValue:) withObjects:subject];

		expect(object.charPointerValue).to.equal(NULL);

		const char *string = "blah blah blah";
		[subject sendNext:@(string)];
		expect(strcmp(object.charPointerValue, string) == 0).to.beTruthy();
	});

	describe(@"the returned subscribable", ^{
		it(@"should send the return value of the method invocation", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSubscribable *subscribable = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withObjects:objectSubject, integerSubject];

			__block NSString *result;
			[subscribable subscribeNext:^(id x) {
				result = x;
			}];

			[objectSubject sendNext:@"Magic number"];
			expect(result).to.beNil();
			
			[integerSubject sendNext:@42];
			expect(result).to.equal(@"Magic number: 42");
		});

		it(@"should send nil for void-returning methods", ^{
			RACSubject *subject = [RACSubject subject];
			RACSubscribable *subscribable = [object rac_liftSelector:@selector(setObjectValue:) withObjects:subject];

			__block BOOL gotNext = NO;
			__block id result;
			[subscribable subscribeNext:^(id x) {
				gotNext = YES;
				result = x;
			}];

			expect(gotNext).to.beFalsy();

			[subject sendNext:@1];

			expect(gotNext).to.beTruthy();
			expect(result).to.beNil();
		});

		it(@"should replay the last value", ^{
			RACSubject *objectSubject = [RACSubject subject];
			RACSubject *integerSubject = [RACSubject subject];
			RACSubscribable *subscribable = [object rac_liftSelector:@selector(combineObjectValue:andIntegerValue:) withObjects:objectSubject, integerSubject];

			__block NSString *result;
			[objectSubject sendNext:@"Magic number"];
			expect(result).to.beNil();

			[integerSubject sendNext:@42];
			expect(result).to.beNil();

			[integerSubject sendNext:@43];
			expect(result).to.beNil();

			[subscribable subscribeNext:^(id x) {
				result = x;
			}];

			expect(result).to.equal(@"Magic number: 43");
		});
	});
});

describe(@"-rac_liftBlock:withObjects:", ^{
	it(@"should invoke the block with the latest value from the subscribables", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];

		__block id received1;
		__block id received2;
		RACSubscribable *subscribable = [self rac_liftBlock:^(NSNumber *arg1, NSNumber *arg2) {
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
		[subscribable subscribeNext:^(id x) {
			received = x;
		}];

		expect(received).to.equal(@3);
	});
});

SpecEnd
