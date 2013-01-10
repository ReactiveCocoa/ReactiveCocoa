//
//  RACPropertySignalExamples.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACSubject.h"

NSString * const RACPropertySignalExamples = @"RACPropertySignalExamples";
NSString * const RACPropertySignalExamplesSetupBlock = @"RACPropertySignalExamplesSetupBlock";

SharedExampleGroupsBegin(RACPropertySignalExamples)

sharedExamplesFor(RACPropertySignalExamples, ^(NSDictionary *data) {
	__block RACTestObject *testObject = nil;
	__block void (^setupBlock)(RACTestObject *, NSString *keyPath, RACSignal *);

	beforeEach(^{
		setupBlock = data[RACPropertySignalExamplesSetupBlock];
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should set the value of the property with the latest value from the signal", ^{
		RACSubject *subject = [RACSubject subject];
		setupBlock(testObject, @keypath(testObject.objectValue), subject);
		expect(testObject.objectValue).to.beNil();

		[subject sendNext:@1];
		expect(testObject.objectValue).to.equal(@1);

		[subject sendNext:@2];
		expect(testObject.objectValue).to.equal(@2);

		[subject sendNext:nil];
		expect(testObject.objectValue).to.beNil();
	});

	it(@"should set the value of a non-object property with the latest value from the signal", ^{
		RACSubject *subject = [RACSubject subject];
		setupBlock(testObject, @keypath(testObject.integerValue), subject);
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

	it(@"should retain intermediate signals when binding", ^{
		RACSubject *subject = [RACSubject subject];
		expect(subject).notTo.beNil();

		__block BOOL deallocd = NO;

		@autoreleasepool {
			@autoreleasepool {
				RACSignal *intermediateSignal = [subject map:^(NSNumber *num) {
					return @(num.integerValue + 1);
				}];

				expect(intermediateSignal).notTo.beNil();

				[intermediateSignal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				setupBlock(testObject, @keypath(testObject.integerValue), intermediateSignal);
			}

			// Spin the run loop to account for RAC magic that retains the
			// signal for a single iteration.
			[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
		}

		expect(deallocd).to.beFalsy();

		[subject sendNext:@5];
		expect(testObject.integerValue).to.equal(6);

		[subject sendNext:@6];
		expect(testObject.integerValue).to.equal(7);

		expect(deallocd).to.beFalsy();
		[subject sendCompleted];

		// Can't test deallocd again, because it's legal for the chain to be
		// retained until the object or the original signal is destroyed.
	});
});

SharedExampleGroupsEnd
