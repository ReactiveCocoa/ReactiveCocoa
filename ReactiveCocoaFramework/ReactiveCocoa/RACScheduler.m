//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACDisposable.h"
#import <libkern/OSAtomic.h>

// The key for the queue-specific current scheduler.
const void * RACSchedulerCurrentSchedulerKey = &RACSchedulerCurrentSchedulerKey;

// The key for the immedate scheduler-specific, thread-specific block queue.
static NSString * const RACSchedulerImmediateSchedulerQueueKey = @"RACSchedulerImmediateSchedulerQueueKey";

@interface RACScheduler ()
@property (nonatomic, readonly, copy) void (^scheduleBlock)(RACScheduler *scheduler, void (^block)(void));
@property (nonatomic, readonly, assign) dispatch_queue_t queue;
@property (nonatomic, readonly, copy) NSString *name;
@end

@implementation RACScheduler

- (void)dealloc {
	if (_queue != NULL) {
		dispatch_release(_queue);
	}
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.name];
}

#pragma mark Initializers

- (id)initWithQueue:(dispatch_queue_t)queue name:(NSString *)name scheduleBlock:(void (^)(RACScheduler *scheduler, void (^block)(void)))block {
	NSParameterAssert(block != NULL);

	self = [super init];
	if (self == nil) return nil;

	_scheduleBlock = [block copy];

	if (queue != NULL) {
		dispatch_retain(queue);
		_queue = queue;
	}

	if (name == nil) {
		if (queue != NULL && dispatch_queue_get_label(queue) != NULL) {
			name = @(dispatch_queue_get_label(queue));
		} else {
			name = @"com.ReactiveCocoa.RACScheduler.anonymousScheduler";
		}
	}

	_name = [name copy];

	return self;
}

- (id)initWithQueue:(dispatch_queue_t)queue {
	NSParameterAssert(queue != NULL);

	return [self initWithQueue:queue name:nil scheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
		dispatch_async(scheduler.queue, block);
	}];
}

- (id)initWithName:(NSString *)name scheduleBlock:(void (^)(RACScheduler *scheduler, void (^block)(void)))scheduleBlock {
	return [self initWithQueue:NULL name:name scheduleBlock:scheduleBlock];
}

#pragma mark Schedulers

+ (instancetype)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [[RACScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.immediateScheduler" scheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			block();
		}];
	});
	
	return immediateScheduler;
}

+ (instancetype)currentQueueScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *currentQueueScheduler;
	dispatch_once(&onceToken, ^{
		currentQueueScheduler = [[RACScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.currentQueueScheduler" scheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			@synchronized(scheduler) {
				NSMutableArray *queue = NSThread.currentThread.threadDictionary[RACSchedulerImmediateSchedulerQueueKey];
				if (queue == nil) {
					queue = [NSMutableArray array];
					NSThread.currentThread.threadDictionary[RACSchedulerImmediateSchedulerQueueKey] = queue;

					[queue addObject:block];

					while (queue.count > 0) {
						void (^dequeuedBlock)(void) = queue[0];
						[queue removeObjectAtIndex:0];
						dequeuedBlock();
					}

					[NSThread.currentThread.threadDictionary removeObjectForKey:RACSchedulerImmediateSchedulerQueueKey];
				} else {
					[queue addObject:block];
				}
			}
		}];
	});

	return currentQueueScheduler;
}

+ (instancetype)mainQueueScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainQueueScheduler;
	dispatch_once(&onceToken, ^{
		dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.mainQueueScheduler", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_main_queue());
		mainQueueScheduler = [[RACScheduler alloc] initWithQueue:queue];
		dispatch_release(queue);
	});
	
	return mainQueueScheduler;
}

+ (instancetype)sharedBackgroundScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *backgroundScheduler;
	dispatch_once(&onceToken, ^{
		dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.sharedBackgroundScheduler", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
		backgroundScheduler = [[RACScheduler alloc] initWithQueue:queue];
		dispatch_release(queue);
	});
	
	return backgroundScheduler;
}

+ (instancetype)deferredScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *deferredScheduler;
	dispatch_once(&onceToken, ^{
		deferredScheduler = [[RACScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.deferredScheduler" scheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			RACScheduler *currentScheduler = RACScheduler.currentScheduler ?: RACScheduler.mainQueueScheduler;
			[currentScheduler schedule:block];
		}];
	});
	
	return deferredScheduler;
}

+ (instancetype)backgroundScheduler {
	dispatch_queue_t queue = dispatch_queue_create("com.ReactiveCocoa.RACScheduler.backgroundScheduler", DISPATCH_QUEUE_SERIAL);
	RACScheduler *scheduler = [[self alloc] initWithQueue:queue];
	dispatch_release(queue);
	return scheduler;
}

+ (instancetype)subscriptionScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *subscriptionScheduler;
	dispatch_once(&onceToken, ^{
		subscriptionScheduler = [[RACScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler" scheduleBlock:^(RACScheduler *scheduler, void (^block)(void)) {
			if (RACScheduler.currentScheduler == nil) {
				[RACScheduler.mainQueueScheduler schedule:block];
			} else {
				block();
			}
		}];
	});

	return subscriptionScheduler;
}

+ (BOOL)onMainThread {
	return NSOperationQueue.currentQueue == NSOperationQueue.mainQueue || [NSThread isMainThread];
}

+ (instancetype)currentScheduler {
	RACScheduler *scheduler = (__bridge id)dispatch_get_specific(RACSchedulerCurrentSchedulerKey);
	if (scheduler != nil) return scheduler;
	if (self.class.onMainThread) return RACScheduler.mainQueueScheduler;

	return nil;
}

#pragma mark Scheduling

- (RACDisposable *)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	__block uint32_t volatile disposed = 0;
	self.scheduleBlock(self, ^{
		if (disposed == 1) return;

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
	NSParameterAssert(block != NULL);

	if (self.queue != NULL) {
		dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, (void *)CFBridgingRetain(self), currentSchedulerRelease);
	}

	block();

	if (self.queue != NULL) {
		dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, nil, currentSchedulerRelease);
	}
}

@end
