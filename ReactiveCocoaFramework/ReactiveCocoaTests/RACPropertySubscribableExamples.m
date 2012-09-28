//
//  RACPropertySubscribableExamples.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACTestObject.h"
#import "RACSubject.h"
#import "NSObject+RACPropertySubscribing.h"

NSString * const RACPropertySubscribableExamples = @"RACPropertySubscribableExamples";
NSString * const RACPropertySubscribableExamplesSetupBlock = @"RACPropertySubscribableExamplesSetupBlock";

SharedExampleGroupsBegin(RACPropertySubscribableExamples)

sharedExamplesFor(RACPropertySubscribableExamples, ^(NSDictionary *data) {
	__block RACTestObject *testObject = nil;
	void (^setupBlock)(RACTestObject *, NSString *keyPath, RACSubject *) = data[RACPropertySubscribableExamplesSetupBlock];

	beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should set the value of the property with the latest value from the subscribable", ^{
		RACSubject *subject = [RACSubject subject];
		setupBlock(testObject, RAC_KEYPATH(testObject, objectValue), subject);
		expect(testObject.objectValue).to.beNil();

		[subject sendNext:@1];
		expect(testObject.objectValue).to.equal(@1);

		[subject sendNext:@2];
		expect(testObject.objectValue).to.equal(@2);

		[subject sendNext:nil];
		expect(testObject.objectValue).to.beNil();
	});

	it(@"should set the value of a non-object property with the latest value from the subscribable", ^{
		RACSubject *subject = [RACSubject subject];
		setupBlock(testObject, RAC_KEYPATH(testObject, integerValue), subject);
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
});

SharedExampleGroupsEnd
