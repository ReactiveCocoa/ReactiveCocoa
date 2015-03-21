//
//  RACSubscriptingAssignmentTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACPropertySignalExamples.h"
#import "RACTestObject.h"
#import "RACSubject.h"

QuickSpecBegin(RACSubscriptingAssignmentTrampolineSpec)

id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal) {
	[[RACSubscriptingAssignmentTrampoline alloc] initWithTarget:testObject nilValue:nilValue][keyPath] = signal;
};

qck_itBehavesLike(RACPropertySignalExamples, ^{
	return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
});

qck_it(@"should expand the RAC macro properly", ^{
	RACSubject *subject = [RACSubject subject];
	RACTestObject *testObject = [[RACTestObject alloc] init];
	RAC(testObject, objectValue) = subject;

	[subject sendNext:@1];
	expect(testObject.objectValue).to(equal(@1));
});

QuickSpecEnd
