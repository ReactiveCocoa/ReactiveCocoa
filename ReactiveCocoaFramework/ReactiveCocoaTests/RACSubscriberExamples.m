//
//  RACSubscriberExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriberExamples.h"

#import "RACSubscriber.h"

NSString * const RACSubscriberExamples = @"RACSubscriberExamples";

SharedExampleGroupsBegin(RACSubscriberExamples)

sharedExamplesFor(RACSubscriberExamples, ^(id<RACSubscriber> (^getSubscriber)(void), void (^verifyNexts)(NSSet *)) {
	__block id<RACSubscriber> subscriber;
	
	beforeEach(^{
		subscriber = getSubscriber();
		expect(subscriber).notTo.beNil();
	});

	it(@"should accept a nil error", ^{
		[subscriber sendError:nil];
	});

	describe(@"with values", ^{
		__block NSSet *values;
		
		beforeEach(^{
			NSMutableSet *mutableValues = [NSMutableSet set];
			for (NSUInteger i = 0; i < 20; i++) {
				[mutableValues addObject:@(i)];
			}

			values = [mutableValues copy];
		});

		it(@"should send nexts serially, even when delivered from multiple threads", ^{
			NSArray *allValues = values.allObjects;
			dispatch_apply(allValues.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), [^(size_t index) {
				[subscriber sendNext:allValues[index]];
			} copy]);

			verifyNexts(values);
		});
	});
});

SharedExampleGroupsEnd
