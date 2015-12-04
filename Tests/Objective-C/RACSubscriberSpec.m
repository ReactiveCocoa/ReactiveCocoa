//
//  RACSubscriberSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSubscriberExamples.h"

#import "RACSubscriber.h"
#import "RACSubscriber+Private.h"
#import <libkern/OSAtomic.h>

QuickSpecBegin(RACSubscriberSpec)

__block RACSubscriber *subscriber;
__block NSMutableArray *values;

__block volatile BOOL finished;
__block volatile int32_t nextsAfterFinished;

__block BOOL success;
__block NSError *error;

qck_beforeEach(^{
	values = [NSMutableArray array];

	finished = NO;
	nextsAfterFinished = 0;

	success = YES;
	error = nil;

	subscriber = [RACSubscriber subscriberWithNext:^(id value) {
		if (finished) OSAtomicIncrement32Barrier(&nextsAfterFinished);

		[values addObject:value];
	} error:^(NSError *e) {
		error = e;
		success = NO;
	} completed:^{
		success = YES;
	}];
});

qck_itBehavesLike(RACSubscriberExamples, ^{
	return @{
		RACSubscriberExampleSubscriber: subscriber,
		RACSubscriberExampleValuesReceivedBlock: [^{ return [values copy]; } copy],
		RACSubscriberExampleErrorReceivedBlock: [^{ return error; } copy],
		RACSubscriberExampleSuccessBlock: [^{ return success; } copy]
	};
});

qck_describe(@"finishing", ^{
	__block void (^sendValues)(void);
	__block BOOL expectedSuccess;

	__block dispatch_group_t dispatchGroup;
	__block dispatch_queue_t concurrentQueue;

	qck_beforeEach(^{
		dispatchGroup = dispatch_group_create();
		expect(dispatchGroup).notTo(beNil());

		concurrentQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACSubscriberSpec", DISPATCH_QUEUE_CONCURRENT);
		expect(concurrentQueue).notTo(beNil());

		dispatch_suspend(concurrentQueue);

		sendValues = [^{
			for (NSUInteger i = 0; i < 15; i++) {
				dispatch_group_async(dispatchGroup, concurrentQueue, ^{
					[subscriber sendNext:@(i)];
				});
			}
		} copy];

		sendValues();
	});

	qck_afterEach(^{
		sendValues();
		dispatch_resume(concurrentQueue);

		// Time out after one second.
		dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC));
		expect(@(dispatch_group_wait(dispatchGroup, time))).to(equal(@0));

		dispatchGroup = NULL;
		concurrentQueue = NULL;

		expect(@(nextsAfterFinished)).to(equal(@0));

		if (expectedSuccess) {
			expect(@(success)).to(beTruthy());
			expect(error).to(beNil());
		} else {
			expect(@(success)).to(beFalsy());
		}
	});

	qck_it(@"should never invoke next after sending completed", ^{
		expectedSuccess = YES;

		dispatch_group_async(dispatchGroup, concurrentQueue, ^{
			[subscriber sendCompleted];

			finished = YES;
			OSMemoryBarrier();
		});
	});

	qck_it(@"should never invoke next after sending error", ^{
		expectedSuccess = NO;

		dispatch_group_async(dispatchGroup, concurrentQueue, ^{
			[subscriber sendError:nil];

			finished = YES;
			OSMemoryBarrier();
		});
	});
});

QuickSpecEnd
