//
//  RACSubscriptingAssignmentTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACPropertySubscribableExamples.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(RACSubscriptingAssignmentTrampoline)

void (^setupBlock)(RACTestObject *, NSString *, RACSubject *) = ^(RACTestObject *testObject, NSString *keyPath, RACSubject *subject) {
	[RACSubscriptingAssignmentTrampoline trampoline][ [[RACSubscriptingAssignmentObjectKeyPathPair alloc] initWithObject:testObject keyPath:keyPath] ] = subject;
};

itShouldBehaveLike(RACPropertySubscribableExamples, @{ RACPropertySubscribableExamplesSetupBlock: setupBlock });

it(@"should expand the RAC macro properly", ^{
	RACSubject *subject = [RACSubject subject];
	RACTestObject *testObject = [[RACTestObject alloc] init];
	RAC(testObject, objectValue) = subject;

	[subject sendNext:@1];
	expect(testObject.objectValue).to.equal(@1);
});

SpecEnd
