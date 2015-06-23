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
#import "RACScheduler.h"
#import "NSObject+RACSelectorSignal.h"

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

qck_it(@"should subscribe the next values on main thread", ^{
	RACSubject *subject = [RACSubject subject];
	RACTestObject *testObject = [[RACTestObject alloc] init];
	RACOnMainThread(testObject, slowObjectValue) = subject;

	[[RACScheduler mainThreadScheduler] schedule:^{
		[subject sendNext:@1];
	}];

	__block BOOL deliverOnMainMethod = NO;
	[[testObject rac_signalForSelector:@selector(setSlowObjectValue:)] subscribeNext:^(id x) {
		deliverOnMainMethod = [NSThread isMainThread];
	}];
	[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	expect(testObject.slowObjectValue).to(equal(@1));
	expect(@(deliverOnMainMethod)).to(beTruthy());
});

qck_it(@"should subscribe the next values on main thread but signal was created in another thread", ^{
	RACSubject *subject = [RACSubject subject];
	RACTestObject *testObject = [[RACTestObject alloc] init];
	RACOnMainThread(testObject, slowObjectValue) = subject;
	
	[[RACScheduler scheduler] schedule:^{
		[subject sendNext:@1];
	}];
	
	__block BOOL deliverOnMainMethod = NO;
	[[testObject rac_signalForSelector:@selector(setSlowObjectValue:)] subscribeNext:^(id x) {
		deliverOnMainMethod = [NSThread isMainThread];
	}];
	[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	expect(testObject.slowObjectValue).to(equal(@1));
	expect(@(deliverOnMainMethod)).to(beTruthy());
});

QuickSpecEnd
