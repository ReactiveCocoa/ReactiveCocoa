//
//  RACSwitchSignalExamples.m
//  ReactiveCocoa
//
//  Created by Robert Böhnke on 7/11/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSwitchSignalExamples.h"

#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

NSString * const RACSwitchSignalExamples = @"RACSwitchSignalExamples";
NSString * const RACSwitchSignalExamplesSetupBlock = @"RACSwitchSignalExamplesSetupBlock";

SharedExampleGroupsBegin(RACSwitchSignalExamples)

sharedExamplesFor(RACSwitchSignalExamples, ^(NSDictionary *data) {
	__block RACSignal *(^setup)(RACSignal *, NSDictionary *);

	__block RACSubject *keySubject;

	__block RACSubject *subjectZero;
	__block RACSubject *subjectOne;
	__block RACSubject *subjectTwo;

	__block RACSubject *defaultSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	__block RACSignal *switchSignal;

	beforeEach(^{
		keySubject = [RACSubject subject];

		subjectZero = [RACSubject subject];
		subjectOne = [RACSubject subject];
		subjectTwo = [RACSubject subject];

		defaultSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		setup = data[RACSwitchSignalExamplesSetupBlock];

		switchSignal = setup(keySubject, @{
			@0: subjectZero,
			@1: subjectOne,
			@2: subjectTwo,
		});

		[switchSignal subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should not send any values before a key is sent", ^{
		[subjectZero sendNext:RACUnit.defaultUnit];
		[subjectOne sendNext:RACUnit.defaultUnit];
		[subjectTwo sendNext:RACUnit.defaultUnit];

		expect(values).to.equal(@[]);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();
	});

	it(@"should send events based on the latest key", ^{
		[keySubject sendNext:@0];

		[subjectZero sendNext:@"zero"];
		[subjectZero sendNext:@"zero"];
		[subjectOne sendNext:@"one"];
		[subjectTwo sendNext:@"two"];

		NSArray *expected = @[ @"zero", @"zero" ];
		expect(values).to.equal(expected);

		[keySubject sendNext:@1];

		[subjectZero sendNext:@"zero"];
		[subjectOne sendNext:@"one"];
		[subjectTwo sendNext:@"two"];

		expected = @[ @"zero", @"zero", @"one" ];
		expect(values).to.equal(expected);

		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[keySubject sendNext:@2];

		[subjectZero sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		[subjectOne sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).to.beNil();

		[subjectTwo sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).notTo.beNil();
	});

	it(@"should not send completed when only the key signal completes", ^{
		[keySubject sendNext:@0];
		[subjectZero sendNext:@"zero"];
		[keySubject sendCompleted];

		expect(values).to.equal(@[ @"zero" ]);
		expect(completed).to.beFalsy();
	});

	it(@"should send completed when the key signal and the latest sent signal complete", ^{
		[keySubject sendNext:@0];
		[subjectZero sendNext:@"zero"];
		[keySubject sendCompleted];
		[subjectZero sendCompleted];

		expect(values).to.equal(@[ @"zero" ]);
		expect(completed).to.beTruthy();
	});
});

SharedExampleGroupsEnd
