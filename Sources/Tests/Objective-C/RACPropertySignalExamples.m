//
//  RACPropertySignalExamples.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"

NSString * const RACPropertySignalExamples = @"RACPropertySignalExamples";
NSString * const RACPropertySignalExamplesSetupBlock = @"RACPropertySignalExamplesSetupBlock";

QuickConfigurationBegin(RACPropertySignalExampleGroups)

+ (void)configure:(Configuration *)configuration {
	sharedExamples(RACPropertySignalExamples, ^(QCKDSLSharedExampleContext exampleContext) {
		__block RACTestObject *testObject = nil;
		__block void (^setupBlock)(RACTestObject *, NSString *keyPath, id nilValue, RACSignal *);

		qck_beforeEach(^{
			setupBlock = exampleContext()[RACPropertySignalExamplesSetupBlock];
			testObject = [[RACTestObject alloc] init];
		});

		qck_it(@"should set the value of the property with the latest value from the signal", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.objectValue), nil, subject);
			expect(testObject.objectValue).to(beNil());

			[subject sendNext:@1];
			expect(testObject.objectValue).to(equal(@1));

			[subject sendNext:@2];
			expect(testObject.objectValue).to(equal(@2));

			[subject sendNext:nil];
			expect(testObject.objectValue).to(beNil());
		});

		qck_it(@"should set the given nilValue for an object property", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.objectValue), @"foo", subject);
			expect(testObject.objectValue).to(beNil());

			[subject sendNext:@1];
			expect(testObject.objectValue).to(equal(@1));

			[subject sendNext:@2];
			expect(testObject.objectValue).to(equal(@2));

			[subject sendNext:nil];
			expect(testObject.objectValue).to(equal(@"foo"));
		});

		qck_it(@"should leave the value of the property alone after the signal completes", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.objectValue), nil, subject);
			expect(testObject.objectValue).to(beNil());

			[subject sendNext:@1];
			expect(testObject.objectValue).to(equal(@1));

			[subject sendCompleted];
			expect(testObject.objectValue).to(equal(@1));
		});

		qck_it(@"should set the value of a non-object property with the latest value from the signal", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.integerValue), nil, subject);
			expect(@(testObject.integerValue)).to(equal(@0));

			[subject sendNext:@1];
			expect(@(testObject.integerValue)).to(equal(@1));

			[subject sendNext:@2];
			expect(@(testObject.integerValue)).to(equal(@2));

			[subject sendNext:@0];
			expect(@(testObject.integerValue)).to(equal(@0));
		});

		qck_it(@"should set the given nilValue for a non-object property", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.integerValue), @42, subject);
			expect(@(testObject.integerValue)).to(equal(@0));

			[subject sendNext:@1];
			expect(@(testObject.integerValue)).to(equal(@1));

			[subject sendNext:@2];
			expect(@(testObject.integerValue)).to(equal(@2));

			[subject sendNext:nil];
			expect(@(testObject.integerValue)).to(equal(@42));
		});

		qck_it(@"should not invoke -setNilValueForKey: with a nilValue", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.integerValue), @42, subject);

			__block BOOL setNilValueForKeyInvoked = NO;
			[[testObject rac_signalForSelector:@selector(setNilValueForKey:)] subscribeNext:^(NSString *key) {
				setNilValueForKeyInvoked = YES;
			}];

			[subject sendNext:nil];
			expect(@(testObject.integerValue)).to(equal(@42));
			expect(@(setNilValueForKeyInvoked)).to(beFalsy());
		});

		qck_it(@"should invoke -setNilValueForKey: without a nilValue", ^{
			RACSubject *subject = [RACSubject subject];
			setupBlock(testObject, @keypath(testObject.integerValue), nil, subject);

			[subject sendNext:@1];
			expect(@(testObject.integerValue)).to(equal(@1));

			testObject.catchSetNilValueForKey = YES;

			__block BOOL setNilValueForKeyInvoked = NO;
			[[testObject rac_signalForSelector:@selector(setNilValueForKey:)] subscribeNext:^(NSString *key) {
				setNilValueForKeyInvoked = YES;
			}];

			[subject sendNext:nil];
			expect(@(testObject.integerValue)).to(equal(@1));
			expect(@(setNilValueForKeyInvoked)).to(beTruthy());
		});
	});
}

QuickConfigurationEnd
