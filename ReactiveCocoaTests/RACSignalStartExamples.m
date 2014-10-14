//
//  RACSignalStartExamples.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/29/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSignalStartExamples.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACScheduler.h"
#import "RACSubscriber.h"
#import "RACMulticastConnection.h"

NSString * const RACSignalStartSharedExamplesName = @"RACSignalStartSharedExamplesName";

NSString * const RACSignalStartSignal = @"RACSignalStartSignal";
NSString * const RACSignalStartExpectedValues = @"RACSignalStartExpectedValues";
NSString * const RACSignalStartExpectedScheduler = @"RACSignalStartExpectedScheduler";

SharedExampleGroupsBegin(RACSignalStartSpec)

sharedExamples(RACSignalStartSharedExamplesName, ^(NSDictionary *data) {
	__block RACSignal *signal;
	__block NSArray *expectedValues;
	__block RACScheduler *scheduler;
	__block RACScheduler * (^subscribeAndGetScheduler)(void);

	qck_beforeEach(^{
		signal = data[RACSignalStartSignal];
		expectedValues = data[RACSignalStartExpectedValues];
		scheduler = data[RACSignalStartExpectedScheduler];

		subscribeAndGetScheduler = [^{
			__block RACScheduler *schedulerInDelivery;
			[signal subscribeNext:^(id _) {
				schedulerInDelivery = RACScheduler.currentScheduler;
			}];

			expect(schedulerInDelivery).willNot.beNil();
			return schedulerInDelivery;
		} copy];
	});

	qck_it(@"should send values from the returned signal", ^{
		NSArray *values = [signal toArray];
		expect(values).to.equal(expectedValues);
	});

	qck_it(@"should replay all values", ^{
		// Force a subscription so that we get replayed results.
		[[signal publish] connect];
		
		NSArray *values = [signal toArray];
		expect(values).to.equal(expectedValues);
	});

	qck_it(@"should deliver the original results on the given scheduler", ^{
		RACScheduler *currentScheduler = subscribeAndGetScheduler();
		expect(currentScheduler).to.equal(scheduler);
	});

	qck_it(@"should deliver replayed results on the given scheduler", ^{
		// Force a subscription so that we get replayed results on the
		// tested subscription.
		subscribeAndGetScheduler();

		RACScheduler *currentScheduler = subscribeAndGetScheduler();
		expect(currentScheduler).to.equal(scheduler);
	});
});

SharedExampleGroupsEnd
