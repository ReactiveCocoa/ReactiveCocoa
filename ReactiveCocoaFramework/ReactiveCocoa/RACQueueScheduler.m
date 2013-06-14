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

@interface RACQueueScheduler ()
@property (nonatomic, readonly) dispatch_queue_t queue;
@end

@implementation RACQueueScheduler

#pragma mark Lifecycle

- (void)dealloc {
	dispatch_release(_queue);
}

- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
	NSCParameterAssert(targetQueue != NULL);

	_queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
	if (_queue == nil) return nil;

	dispatch_set_target_queue(_queue, targetQueue);
	
	return [super initWithName:name];
}

#pragma mark Current Scheduler

static void currentSchedulerRelease(void *context) {
	CFBridgingRelease(context);
}

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, (void *)CFBridgingRetain(self), currentSchedulerRelease);
	block();
	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, nil, currentSchedulerRelease);
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	RACDisposable *disposable = [[RACDisposable alloc] init];

	dispatch_async(self.queue, ^{
		if (disposable.disposed) return;
		[self performAsCurrentScheduler:block];
	});

	return disposable;
}

- (RACDisposable *)after:(dispatch_time_t)when schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	RACDisposable *disposable = [[RACDisposable alloc] init];

	dispatch_after(when, self.queue, ^{
		if (disposable.disposed) return;
		[self performAsCurrentScheduler:block];
	});

	return disposable;
}

@end
