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
#import "RACQueueScheduler+Subclass.h"
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

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	__block volatile uint32_t disposed = 0;

	dispatch_async(self.queue, ^{
		if (disposed != 0) return;
		[self performAsCurrentScheduler:block];
	});

	return [RACDisposable disposableWithBlock:^{
		OSAtomicOr32Barrier(1, &disposed);
	}];
}

- (RACDisposable *)after:(dispatch_time_t)when schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	__block volatile uint32_t disposed = 0;

	dispatch_after(when, self.queue, ^{
		if (disposed != 0) return;
		[self performAsCurrentScheduler:block];
	});

	return [RACDisposable disposableWithBlock:^{
		OSAtomicOr32Barrier(1, &disposed);
	}];
}

static void currentSchedulerRelease(void *context) {
	CFBridgingRelease(context);
}

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	// If we're using a concurrent queue, we could end up in here concurrently,
	// in which case we *don't* want to clear the current scheduler immediately
	// after our block is done executing, but only after our performs are done.
	OSAtomicIncrement32Barrier(&_performCount);

	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, (void *)CFBridgingRetain(self), currentSchedulerRelease);
	block();

	int32_t count = OSAtomicDecrement32Barrier(&_performCount);
	if (count == 0) {
		dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, nil, currentSchedulerRelease);
	}
}

@end
