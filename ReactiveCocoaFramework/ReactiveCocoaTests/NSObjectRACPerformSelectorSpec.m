//
//  NSObjectRACPerformSelectorSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSObject+RACPerformSelector.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(NSObjectRACPerformSelector)

__block RACTestObject *object;

beforeEach(^{
	object = [[RACTestObject alloc] init];
});

it(@"should call the selector with the value of the subscribable", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_performSelector:@selector(setObjectValue:) withObjects:subject, nil];

	expect(object.objectValue).to.beNil();

	[subject sendNext:@1];
	expect(object.objectValue).to.equal(@1);

	[subject sendNext:@42];
	expect(object.objectValue).to.equal(@42);
});

it(@"should call the selector with the value of the subscribable unboxed", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_performSelector:@selector(setIntegerValue:) withObjects:subject, nil];

	expect(object.integerValue).to.equal(0);

	[subject sendNext:@1];
	expect(object.integerValue).to.equal(1);

	[subject sendNext:@42];
	expect(object.integerValue).to.equal(42);
});

it(@"should should work with multiple arguments", ^{
	RACSubject *objectValueSubject = [RACSubject subject];
	RACSubject *integerValueSubject = [RACSubject subject];
	[object rac_performSelector:@selector(setObjectValue:andIntegerValue:) withObjects:objectValueSubject, integerValueSubject, nil];

	expect(object.objectValue).to.beNil();
	expect(object.integerValue).to.equal(0);

	[objectValueSubject sendNext:@1];
	expect(object.objectValue).to.equal(@1);
	expect(object.integerValue).to.equal(0);

	[integerValueSubject sendNext:@42];
	expect(object.objectValue).to.equal(@1);
	expect(object.integerValue).to.equal(42);
});

SpecEnd
