//
//  NSObjectRACSubscribeSelector.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSObject+RACSubscribeSelector.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(NSObjectRACSubscribeSelector)

__block RACTestObject *object;

beforeEach(^{
	object = [[RACTestObject alloc] init];
});

it(@"should call the selector with the value of the subscribable", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setObjectValue:) withObjects:subject];

	expect(object.objectValue).to.beNil();

	[subject sendNext:@1];
	expect(object.objectValue).to.equal(@1);

	[subject sendNext:@42];
	expect(object.objectValue).to.equal(@42);
});

it(@"should call the selector with the value of the subscribable unboxed", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setIntegerValue:) withObjects:subject];

	expect(object.integerValue).to.equal(0);

	[subject sendNext:@1];
	expect(object.integerValue).to.equal(1);

	[subject sendNext:@42];
	expect(object.integerValue).to.equal(42);
});

it(@"should work with multiple arguments", ^{
	RACSubject *objectValueSubject = [RACSubject subject];
	RACSubject *integerValueSubject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setObjectValue:andIntegerValue:) withObjects:objectValueSubject, integerValueSubject];

	expect(object.objectValue).to.beNil();
	expect(object.integerValue).to.equal(0);

	[objectValueSubject sendNext:@1];
	expect(object.objectValue).to.equal(@1);
	expect(object.integerValue).to.equal(0);

	[integerValueSubject sendNext:@42];
	expect(object.objectValue).to.equal(@1);
	expect(object.integerValue).to.equal(42);
});

it(@"should work with subscribables that immediately start with a value", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setObjectValue:) withObjects:[subject startWith:@42]];

	expect(object.objectValue).to.equal(@42);

	[subject sendNext:@1];
	expect(object.objectValue).to.equal(@1);
});

it(@"shouldn't do anything when it isn't given any subscribable arguments", ^{
	[object rac_subscribeSelector:@selector(setObjectValue:) withObjects:@42];

	expect(object.objectValue).to.beNil();

});

it(@"should work with class objects", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setObjectValue:) withObjects:subject];

	expect(object.objectValue).to.equal(nil);

	[subject sendNext:self.class];
	expect(object.objectValue).to.equal(self.class);
});

it(@"should work for char pointer", ^{
	RACSubject *subject = [RACSubject subject];
	[object rac_subscribeSelector:@selector(setCharPointerValue:) withObjects:subject];

	expect(object.charPointerValue).to.equal(NULL);

	const char *string = "blah blah blah";
	[subject sendNext:@(string)];
	expect(strcmp(object.charPointerValue, string) == 0).to.beTruthy();
});

SpecEnd
