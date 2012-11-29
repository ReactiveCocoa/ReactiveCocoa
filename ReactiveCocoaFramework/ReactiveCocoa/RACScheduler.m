//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACDisposable.h"
#import <libkern/OSAtomic.h>

const void * RACSchedulerCurrentSchedulerKey = &RACSchedulerCurrentSchedulerKey;

const void * RACSchedulerImmediateSchedulerQueueKey = &RACSchedulerImmediateSchedulerQueueKey;

@interface RACScheduler ()
@property (nonatomic, copy) void (^scheduleBlock)(RACScheduler *scheduler, void (^block)(void));
@property (nonatomic, assign) dispatch_queue_t queue;
@end

@implementation RACScheduler

- (void)dealloc {
	dispatch_release(_queue);
}

#pragma mark API

- (id)initWithQueue:(dispatch_queue_t)queue concurrent:(BOOL)concurrent {
	NSParameterAssert(queue != NULL);

	self = [self initWithScheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
		dispatch_async(scheduler.queue, block);
	}];
	
	if (self == nil) return nil;

	dispatch_retain(queue);
	_queue = queue;

	dispatch_queue_set_specific(_queue, RACSchedulerCurrentSchedulerKey, (__bridge void *)self, NULL);

	_concurrent = concurrent;
	
	return self;
}

- (id)initWithScheduleBlock:(void (^)(RACScheduler *scheduler, void (^block)(void)))scheduleBlock {
	NSParameterAssert(scheduleBlock != NULL);

	self = [super init];
	if (self == nil) return nil;

	_scheduleBlock = [scheduleBlock copy];

	return self;
}

+ (instancetype)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler = nil;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [[RACScheduler alloc] initWithScheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			@synchronized(scheduler) {
				NSMutableArray *queue = (__bridge id)dispatch_get_specific(RACSchedulerImmediateSchedulerQueueKey);
				if (queue == nil) {
					queue = [NSMutableArray array];
					if (scheduler.queue != NULL) {
						dispatch_queue_set_specific(scheduler.queue, RACSchedulerImmediateSchedulerQueueKey, (__bridge void *)queue, NULL);
					}

					[queue addObject:block];

					while (queue.count > 0) {
						void (^dequeuedBlock)(void) = queue[0];
						[queue removeObjectAtIndex:0];
						dequeuedBlock();
					}

					if (scheduler.queue != NULL) {
						dispatch_queue_set_specific(scheduler.queue, RACSchedulerImmediateSchedulerQueueKey, nil, NULL);
					}
				} else {
					[queue addObject:block];
				}
			}
		}];
	});
	
	return immediateScheduler;
}

+ (instancetype)mainQueueScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainQueueScheduler = nil;
	dispatch_once(&onceToken, ^{
		dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.mainQueueScheduler", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_main_queue());
		mainQueueScheduler = [[RACScheduler alloc] initWithQueue:queue concurrent:NO];
		dispatch_release(queue);
	});
	
	return mainQueueScheduler;
}

+ (instancetype)backgroundScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *backgroundScheduler = nil;
	dispatch_once(&onceToken, ^{
		dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.backgroundQueueScheduler", DISPATCH_QUEUE_CONCURRENT);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
		backgroundScheduler = [[RACScheduler alloc] initWithQueue:queue concurrent:YES];
		dispatch_release(queue);
	});
	
	return backgroundScheduler;
}

+ (instancetype)deferredScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *deferredScheduler = nil;
	dispatch_once(&onceToken, ^{
		deferredScheduler = [[RACScheduler alloc] initWithScheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			RACScheduler *currentScheduler = RACScheduler.currentScheduler ?: RACScheduler.mainQueueScheduler;
			[currentScheduler schedule:block];
		}];
	});
	
	return deferredScheduler;
}

+ (instancetype)serialScheduler {
	dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.serialScheduler", DISPATCH_QUEUE_SERIAL);
	RACScheduler *scheduler = [[self alloc] initWithQueue:queue concurrent:NO];
	dispatch_release(queue);
	return scheduler;
}

+ (instancetype)concurrentScheduler {
	dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.concurrentScheduler", DISPATCH_QUEUE_CONCURRENT);
	RACScheduler *scheduler = [[self alloc] initWithQueue:queue concurrent:YES];
	dispatch_release(queue);
	return scheduler;
}

- (instancetype)asSerialScheduler {
	if (!self.concurrent) return self;

	NSParameterAssert(self.queue != NULL);

	dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.asSerialScheduler", DISPATCH_QUEUE_SERIAL);
	dispatch_set_target_queue(queue, self.queue);
	RACScheduler *serializedScheduler = [[RACScheduler alloc] initWithQueue:queue concurrent:NO];
	dispatch_release(queue);
	return serializedScheduler;
}

+ (instancetype)currentScheduler {
	return (__bridge id)dispatch_get_specific(RACSchedulerCurrentSchedulerKey);
}

- (RACDisposable *)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	__block uint32_t volatile disposed = 0;
	self.scheduleBlock(self, ^{
		if (disposed == 1) return;

		block();
	});

	return [RACDisposable disposableWithBlock:^{
		OSAtomicOr32Barrier(1, &disposed);
	}];
}

- (dispatch_queue_t)queue {
	if (_queue != NULL) return _queue;

	return RACScheduler.currentScheduler.queue;
}

- (BOOL)concurrent {
	if (_queue != NULL) return _concurrent;

	return RACScheduler.currentScheduler.concurrent;
}

@end
