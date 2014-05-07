//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACCompoundDisposable;
@class RACEvent;
@class RACScheduler;

/// Represents any object which can directly receive values from a RACSignal.
///
/// You generally shouldn't need to implement this protocol. +[RACSignal
/// create:], or a `RACSubscriber` instance with -[RACSignal connect:] should
/// work for most uses.
///
/// Implementors of this protocol may receive messages and values from multiple
/// threads simultaneously, and so should be thread-safe. Subscribers will also
/// be weakly referenced so implementations must allow that.
@protocol RACSubscriber <NSObject>
@required

/// The subscriber's disposable.
///
/// When the receiver is connected to a signal, the disposable representing
/// that connection should be added to this compound disposable.
///
/// A subscriber may receive multiple disposables if it gets connected to
/// multiple signals; however, `error` or `completed` events from any
/// connection must terminate _all_ of them.
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

/// Sends the next value to subscribers.
///
/// value - The value to send. This can be `nil`.
- (void)sendNext:(id)value;

/// Sends the error to subscribers.
///
/// error - The error to send. This can be `nil`.
///
/// This terminates the connection, and invalidates the subscriber (such that
/// it cannot connect to anything else in the future).
- (void)sendError:(NSError *)error;

/// Sends completed to subscribers.
///
/// This terminates the connection, and invalidates the subscriber (such that
/// it cannot connect to anything else in the future).
- (void)sendCompleted;

/// Sends the given event to subscribers.
///
/// event - The event to send. Must not be nil.
- (void)sendEvent:(RACEvent *)event;

@end

/// A subscriber that always delivers its events on a particular scheduler.
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
@interface RACSubscriber : NSObject <RACSubscriber>

/// Invokes -initWithScheduler: with the immediate scheduler.
///
/// This will result in a subscriber that runs its event handlers on one of the
/// schedulers that events are received upon (it's unspecified which one will
/// be picked).
- (instancetype)init;

/// Initializes the receiver, bound to the given scheduler.
///
/// This is the designated initializer for this class.
///
/// scheduler - The scheduler to run all event handlers upon. This can be
///             RACScheduler.immediateScheduler, to dequeue events and run
///             handlers on one of the schedulers that events are received
///             upon (it's unspecified which one will be picked). This argument
///             must not be nil.
- (instancetype)initWithScheduler:(RACScheduler *)scheduler;

/// Creates a subscriber, bound to the given scheduler, and adds the given event handlers.
///
/// scheduler        - The scheduler to run all event handlers upon. This can be
///                    RACScheduler.immediateScheduler, to dequeue events and
///                    run handlers on one of the schedulers that events are
///                    received upon (it's unspecified which one will be
///                    picked). This argument must not be nil.
/// nextHandler      - A block to run to handle dequeued and delivered `next`
///                    events. This may be nil.
/// errorHandler     - A block to run to handle dequeued and delivered `error`
///                    events. This may be nil.
/// completedHandler - A block to run to handle dequeued and delivered
///                    `completed` events. This may be nil.
+ (instancetype)subscriberWithScheduler:(RACScheduler *)scheduler nextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler;

/// Invokes +subscriberWithScheduler:nextHandler:errorHandler:completedHandler:
/// with the immediate scheduler.
///
/// This will result in a subscriber that runs its event handlers on one of the
/// schedulers that events are received upon (it's unspecified which one will
/// be picked).
+ (instancetype)subscriberWithNextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler;

/// Registers a block that will be invoked when an event is dequeued and ready
/// to be handled.
- (void)addEventHandler:(void (^)(RACEvent *))eventHandler;

/// Registers the given blocks to be invoked when events are dequeued and ready
/// to be handled.
///
/// nextHandler      - A block to run to handle dequeued and delivered `next`
///                    events. This may be nil.
/// errorHandler     - A block to run to handle dequeued and delivered `error`
///                    events. This may be nil.
/// completedHandler - A block to run to handle dequeued and delivered
///                    `completed` events. This may be nil.
- (void)addNextHandler:(void (^)(id x))nextHandler errorHandler:(void (^)(NSError *error))errorHandler completedHandler:(void (^)(void))completedHandler;

- (void)addNextHandler:(void (^)(id x))nextHandler;
- (void)addErrorHandler:(void (^)(NSError *error))errorHandler;
- (void)addCompletedHandler:(void (^)(void))completedHandler;

@end
