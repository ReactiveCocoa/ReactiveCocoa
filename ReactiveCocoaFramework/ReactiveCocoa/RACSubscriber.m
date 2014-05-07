//
//  RACSubscriber.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-05-07.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"

#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACScheduler.h"
#import "RACSignal.h"

#import <libkern/OSAtomic.h>

@interface RACSubscriber () {
	volatile int32_t _pendingEventCount;

	OSSpinLock _pendingEventsLock;
	OSSpinLock _handlersLock;
}

@property (nonatomic, strong, readonly) NSMutableArray *pendingEvents;
@property (nonatomic, copy) NSArray *handlers;
@property (nonatomic, strong, readonly) RACScheduler *scheduler;

@end

@implementation RACSubscriber

#pragma mark Properties

// FIXME: Remove?
@synthesize disposable = _disposable;

#pragma mark Lifecycle

- (instancetype)init {
	return [self initWithScheduler:RACScheduler.immediateScheduler];
}

- (instancetype)initWithScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);

	self = [super init];
	if (self == nil) return nil;

	_pendingEvents = [NSMutableArray array];
	_handlers = [NSMutableArray array];
	_scheduler = scheduler;

	return self;
}

+ (instancetype)subscriberWithScheduler:(RACScheduler *)scheduler nextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler {
	RACSubscriber *subscriber = [[self alloc] initWithScheduler:scheduler];
	[subscriber addNextHandler:nextHandler errorHandler:errorHandler completedHandler:completedHandler];
	return subscriber;
}

+ (instancetype)subscriberWithNextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler {
	return [self subscriberWithScheduler:RACScheduler.immediateScheduler nextHandler:nextHandler errorHandler:errorHandler completedHandler:completedHandler];
}

#pragma mark Handler Registration

- (RACDisposable *)addEventHandler:(void (^)(RACEvent *))eventHandler {
	NSCParameterAssert(eventHandler != nil);

	eventHandler = [eventHandler copy];

	OSSpinLockLock(&_handlersLock);
	self.handlers = [self.handlers arrayByAddingObject:eventHandler];
	OSSpinLockUnlock(&_handlersLock);

	return [RACDisposable disposableWithBlock:^{
		OSSpinLockLock(&_handlersLock);
		NSMutableArray *handlers = [self.handlers mutableCopy];
		[handlers removeObjectIdenticalTo:eventHandler];
		self.handlers = handlers;
		OSSpinLockUnlock(&_handlersLock);
	}];
}

- (RACDisposable *)addNextHandler:(void (^)(id x))nextHandler {
	return [self addNextHandler:nextHandler errorHandler:nil completedHandler:nil];
}

- (RACDisposable *)addErrorHandler:(void (^)(NSError *error))errorHandler {
	return [self addNextHandler:nil errorHandler:errorHandler completedHandler:nil];
}

- (RACDisposable *)addCompletedHandler:(void (^)(void))completedHandler {
	return [self addNextHandler:nil errorHandler:nil completedHandler:completedHandler];
}

- (RACDisposable *)addNextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler {
	return [self addEventHandler:^(RACEvent *event) {
		switch (event.eventType) {
			case RACEventTypeNext:
				if (nextHandler != nil) nextHandler(event.value);
				break;

			case RACEventTypeError:
				if (errorHandler != nil) errorHandler(event.error);
				break;

			case RACEventTypeCompleted:
				if (completedHandler != nil) completedHandler();
				break;
		}
	}];
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

- (RACSignal *)events {
	return [RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *disposable = [self addEventHandler:^(RACEvent *event) {
			[subscriber sendEvent:event];
		}];

		[subscriber.disposable addDisposable:disposable];
	}];
}

@end
