//
//  RACTargetQueueSchedulerSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/7/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTargetQueueScheduler.h"
#import <libkern/OSAtomic.h>

QuickSpecBegin(RACTargetQueueSchedulerSpec)

qck_it(@"should have a valid current scheduler", ^{
	dispatch_queue_t queue = dispatch_queue_create("test-queue", DISPATCH_QUEUE_SERIAL);
	RACScheduler *scheduler = [[RACTargetQueueScheduler alloc] initWithName:@"test-scheduler" targetQueue:queue];
	__block RACScheduler *currentScheduler;
	[scheduler schedule:^{
		currentScheduler = RACScheduler.currentScheduler;
	}];

	expect(currentScheduler).toEventually(equal(scheduler));
});

qck_it(@"should schedule blocks FIFO even when given a concurrent queue", ^{
	dispatch_queue_t queue = dispatch_queue_create("test-queue", DISPATCH_QUEUE_CONCURRENT);
	RACScheduler *scheduler = [[RACTargetQueueScheduler alloc] initWithName:@"test-scheduler" targetQueue:queue];
	__block volatile int32_t startedCount = 0;
	__block volatile uint32_t waitInFirst = 1;
	[scheduler schedule:^{
		OSAtomicIncrement32Barrier(&startedCount);
		while (waitInFirst == 1) ;
	}];

	[scheduler schedule:^{
		OSAtomicIncrement32Barrier(&startedCount);
	}];

	expect(@(startedCount)).toEventually(equal(@1));

	OSAtomicAnd32Barrier(0, &waitInFirst);

	expect(@(startedCount)).toEventually(equal(@2));
});

QuickSpecEnd
