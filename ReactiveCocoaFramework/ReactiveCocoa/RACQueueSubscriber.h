//
//  RACQueueSubscriber.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-05-07.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"

@class RACEvent;
@class RACScheduler;

/// A private subscriber that always delivers its events on a particular
/// scheduler.
///
/// Events sent to the subscriber will be added to a FIFO queue for delivery.
/// When the queue is empty and the first event is added, delivery will be
/// scheduled on the subscriber's scheduler (or begin synchronously, if already
/// running on the desired scheduler). Events sent from other threads during
/// this time will be pushed onto the end of the queue being processed.
///
/// This means that -sendNext:, etc. messages sent to the receiver _may not_
/// completely deliver the event before returning, in the presence of recursive
/// event delivery or events being delivered from a different scheduler than the
/// subscriber is bound to.
@interface RACQueueSubscriber : NSObject <RACSubscriber>

/// Initializes the receiver, bound to the given scheduler.
///
/// scheduler - The scheduler to run all event handlers upon. This can be
///             RACScheduler.immediateScheduler, to dequeue events and run
///             handlers upon whatever scheduler the initial event was received
///             upon.
- (instancetype)initWithScheduler:(RACScheduler *)scheduler;

/// Registers a block that will be invoked when an event is dequeued and ready
/// to be handled.
- (void)addEventHandler:(void (^)(RACEvent *))eventHandler;

@end
