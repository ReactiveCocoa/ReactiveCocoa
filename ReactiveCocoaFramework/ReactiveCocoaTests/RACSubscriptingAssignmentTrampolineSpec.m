//
//  RACSubscriptingAssignmentTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(RACSubscriptingAssignmentTrampoline)

__block RACTestObject *testObject = nil;

beforeEach(^{
	testObject = [[RACTestObject alloc] init];
});

it(@"should set the value of the property with the latest value from the subscribable", ^{
	RACSubject *subject = [RACSubject subject];
	RAC_OBJ(testObject, objectValue) = subject;
	expect(testObject.objectValue).to.beNil();

	[subject sendNext:@1];
	expect(testObject.objectValue).to.equal(@1);

	[subject sendNext:@2];
	expect(testObject.objectValue).to.equal(@2);

	[subject sendNext:nil];
	expect(testObject.objectValue).to.beNil();
});

it(@"should with a non-object property", ^{
	RACSubject *subject = [RACSubject subject];
	RAC_OBJ(testObject, integerValue) = subject;
	expect(testObject.integerValue).to.equal(0);

	[subject sendNext:@1];
	expect(testObject.integerValue).to.equal(1);

	[subject sendNext:@2];
	expect(testObject.integerValue).to.equal(2);

	[subject sendNext:@0];
	expect(testObject.integerValue).to.equal(0);

	[subject sendNext:nil];
	expect(testObject.integerValue).to.equal(0);
});

SpecEnd
