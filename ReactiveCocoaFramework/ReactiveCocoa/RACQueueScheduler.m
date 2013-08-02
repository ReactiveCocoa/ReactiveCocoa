//
//  RACQueueScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACQueueScheduler.h"
#import "RACBacktrace.h"
#import "RACDisposable.h"
#import "RACQueueScheduler+Subclass.h"
#import "RACScheduler+Private.h"

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

#pragma mark Date Conversions

+ (dispatch_time_t)wallTimeWithDate:(NSDate *)date {
	NSCParameterAssert(date != nil);

	double seconds = 0;
	double frac = modf(date.timeIntervalSince1970, &seconds);

	struct timespec walltime = {
		.tv_sec = (time_t)fmin(fmax(seconds, LONG_MIN), LONG_MAX),
		.tv_nsec = (long)fmin(fmax(frac * NSEC_PER_SEC, LONG_MIN), LONG_MAX)
	};

	return dispatch_walltime(&walltime, 0);
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

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
	NSCParameterAssert(date != nil);
	NSCParameterAssert(block != NULL);

	RACDisposable *disposable = [[RACDisposable alloc] init];

	dispatch_after([self.class wallTimeWithDate:date], self.queue, ^{
		if (disposable.disposed) return;
		[self performAsCurrentScheduler:block];
	});

	return disposable;
}

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
	NSCParameterAssert(date != nil);
	NSCParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
	NSCParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);
	NSCParameterAssert(block != NULL);

	uint64_t intervalInNanoSecs = (uint64_t)(interval * NSEC_PER_SEC);
	uint64_t leewayInNanoSecs = (uint64_t)(leeway * NSEC_PER_SEC);

	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
	dispatch_source_set_timer(timer, [self.class wallTimeWithDate:date], intervalInNanoSecs, leewayInNanoSecs);
	dispatch_source_set_event_handler(timer, block);
	dispatch_resume(timer);

	return [RACDisposable disposableWithBlock:^{
		dispatch_source_cancel(timer);
		dispatch_release(timer);
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
