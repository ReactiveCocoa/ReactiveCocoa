//
//  RACSubscriptingAssignmentTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACPropertySignalExamples.h"
#import "RACTestObject.h"
#import "RACSubject.h"

SpecBegin(RACSubscriptingAssignmentTrampoline)

id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id<RACSignal> signal) {
	[RACSubscriptingAssignmentTrampoline trampoline][ [[RACSubscriptingAssignmentObjectKeyPathPair alloc] initWithObject:testObject keyPath:keyPath] ] = signal;
};

itShouldBehaveLike(RACPropertySignalExamples, @{ RACPropertySignalExamplesSetupBlock: setupBlock }, nil);

it(@"should expand the RAC macro properly", ^{
	RACSubject *subject = [RACSubject subject];
	RACTestObject *testObject = [[RACTestObject alloc] init];
	RAC(testObject, objectValue) = subject;

	[subject sendNext:@1];
	expect(testObject.objectValue).to.equal(@1);
});

SpecEnd
