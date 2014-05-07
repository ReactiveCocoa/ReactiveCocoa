//
//  RACQueueSubscriber.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-05-07.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACQueueSubscriber.h"

#import "RACEvent.h"
#import "RACScheduler.h"

#import <libkern/OSAtomic.h>

@interface RACQueueSubscriber () {
	volatile int32_t _pendingEventCount;

	OSSpinLock _pendingEventsLock;
	OSSpinLock _handlersLock;
}

@property (nonatomic, strong, readonly) NSMutableArray *pendingEvents;
@property (nonatomic, copy) NSArray *handlers;
@property (nonatomic, strong, readonly) RACScheduler *scheduler;

@end

@implementation RACQueueSubscriber

#pragma mark Properties

// FIXME: Remove?
@synthesize disposable = _disposable;

#pragma mark Lifecycle

- (instancetype)initWithScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);

	self = [super init];
	if (self == nil) return nil;

	_pendingEvents = [NSMutableArray array];
	_handlers = [NSMutableArray array];
	_scheduler = scheduler;

	return self;
}

#pragma mark Handler Registration

- (void)addEventHandler:(void (^)(RACEvent *))eventHandler {
	NSCParameterAssert(eventHandler != nil);

	eventHandler = [eventHandler copy];

	OSSpinLockLock(&_handlersLock);
	self.handlers = [self.handlers arrayByAddingObject:eventHandler];
	OSSpinLockUnlock(&_handlersLock);
}

#pragma mark Event Handling

- (void)sendNext:(id)value {
	[self sendEvent:[RACEvent eventWithValue:value]];
}

- (void)sendError:(NSError *)error {
	[self sendEvent:[RACEvent eventWithError:error]];
}

- (void)sendCompleted {
	[self sendEvent:RACEvent.completedEvent];
}

- (void)sendEvent:(RACEvent *)event {
	NSCParameterAssert(event != nil);

	OSSpinLockLock(&_pendingEventsLock);
	[self.pendingEvents addObject:event];
	OSSpinLockUnlock(&_pendingEventsLock);

	// If there's a pending event count, it means another thread is already
	// responsible for dequeuing everything.
	if (OSAtomicIncrement32(&_pendingEventCount) > 1) return;

	// While normally this kind of check could violate ordering, we already
	// guarantee in-order event delivery with our queuing logic. This just
	// allows us to dequeue events synchronously if we're already running on the
	// desired scheduler, instead of waiting an iteration to do so.
	if (RACScheduler.currentScheduler == self.scheduler) {
		[self deliverAllPendingEvents];
	} else {
		[self.scheduler schedule:^{
			[self deliverAllPendingEvents];
		}];
	}
}

- (void)deliverAllPendingEvents {
	OSSpinLockLock(&_handlersLock);
	NSArray *handlers = [self.handlers copy];
	OSSpinLockUnlock(&_handlersLock);

	do {
		OSSpinLockLock(&_pendingEventsLock);
		RACEvent *event = self.pendingEvents.lastObject;
		[self.pendingEvents removeLastObject];
		OSSpinLockUnlock(&_pendingEventsLock);

		for (void (^handler)(RACEvent *) in handlers) {
			handler(event);
		}
	
	// Keep dequeuing and delivering events until other threads stop enqueuing
	// them.
	} while (OSAtomicDecrement32(&_pendingEventCount) > 0);
}

@end
