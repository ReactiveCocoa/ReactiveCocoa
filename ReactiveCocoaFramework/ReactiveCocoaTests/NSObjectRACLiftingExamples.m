//
//  NSObjectRACLiftingExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 22/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObjectRACLiftingExamples.h"
#import "NSObject+RACLifting.h"
#import "RACTestObject.h"
#import "RACSubject.h"
#import "RACTuple.h"
#import "RACDisposable.h"
#import "NSObject+RACPropertySubscribing.h"

NSString * const RACLiftingTestRigName = @"RACLiftingTestRigName";
NSString * const RACLiftingSelectorTestRigName = @"RACLiftingSelectorTestRig";
NSString * const RACLiftingHOMTestRigName = @"RACLiftingHOMTestRig";

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

SpecBegin(NSObjectRACLiftingExamples)

sharedExamplesFor(@"RACLifting", ^(NSDictionary *data) {
	__block RACTestObject *object;
	__block id<RACLiftingTestRig> testRig;
	
	beforeEach(^{
		object = [RACTestObject new];
		testRig = [NSClassFromString(data[RACLiftingTestRigName]) new];
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
	
	it(@"should work with nil arguments", ^{
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:nil];
		
		expect(object.objectValue).to.equal(nil);
	});
	
	it(@"should work with signals that send nil", ^{
		RACSubject *subject = [RACSubject subject];
		[object rac_liftSelector:@selector(setObjectValue:) withObjects:subject];
		
		[subject sendNext:nil];
		expect(object.objectValue).to.equal(nil);
		
		[subject sendNext:RACTupleNil.tupleNil];
		expect(object.objectValue).to.equal(nil);
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
			
			testRig = [NSClassFromString(data[RACLiftingTestRigName]) new];
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
