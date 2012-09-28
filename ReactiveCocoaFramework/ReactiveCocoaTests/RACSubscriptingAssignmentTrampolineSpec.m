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

SpecEnd
