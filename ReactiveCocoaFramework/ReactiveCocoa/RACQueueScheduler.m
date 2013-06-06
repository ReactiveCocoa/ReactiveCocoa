//
//  RACQueueScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACQueueScheduler.h"
#import "RACDisposable.h"
#import "RACScheduler+Private.h"
#import <libkern/OSAtomic.h>

@interface RACQueueScheduler () {
	int32_t _performCount;
}

@end

@implementation RACQueueScheduler

#pragma mark Lifecycle

- (void)dealloc {
	dispatch_release(_queue);
}

- (id)initWithQueue:(dispatch_queue_t)queue {
	NSCParameterAssert(queue != NULL);

	self = [super init];
	if (self == nil) return nil;

	dispatch_retain(queue);
	_queue = queue;

	return self;
}

#pragma mark Current Scheduler

static void currentSchedulerRelease(void *context) {
	CFBridgingRelease(context);
}

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	OSAtomicIncrement32Barrier(&_performCount);

	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, (void *)CFBridgingRetain(self), currentSchedulerRelease);
	block();

	int32_t count = OSAtomicDecrement32Barrier(&_performCount);
	if (count == 0) {
		dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, nil, currentSchedulerRelease);
	}
}

@end
