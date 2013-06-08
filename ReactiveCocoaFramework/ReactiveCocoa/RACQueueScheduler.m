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

@implementation RACQueueScheduler

#pragma mark Lifecycle

- (void)dealloc {
	dispatch_release(_queue);
}

- (id)initWithName:(NSString *)name queue:(dispatch_queue_t)queue {
	NSCParameterAssert(queue != NULL);

	self = [super initWithName:name];
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

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	// If we're using a concurrent queue, we could end up in here concurrently,
	// in which case we *don't* want to clear the current scheduler immediately
	// after our block is done executing, but only *after* all our concurrent
	// invocations are done.

	RACScheduler *previousScheduler = RACScheduler.currentScheduler;
	NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = self;

	block();

	if (previousScheduler != nil) {
		NSThread.currentThread.threadDictionary[RACSchedulerCurrentSchedulerKey] = previousScheduler;
	} else {
		[NSThread.currentThread.threadDictionary removeObjectForKey:RACSchedulerCurrentSchedulerKey];
	}
}

@end
