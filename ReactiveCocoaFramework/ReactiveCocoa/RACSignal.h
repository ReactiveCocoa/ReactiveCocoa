//
//  RACSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/RACStream.h>

@class RACDisposable;
@class RACScheduler;
@class RACSubject;
@protocol RACSubscriber;

@interface RACSignal : RACStream

// Creates a new signal. This is the preferred way to create a new signal
// operation or behavior.
//
// Events can be sent to new subscribers immediately in the `didSubscribe`
// block, but the subscriber will not be able to dispose of the signal until
// a RACDisposable is returned from `didSubscribe`. In the case of infinite
// signals, this won't _ever_ happen if events are sent immediately.
//
// To ensure that the signal is disposable, events can be scheduled on the
// +[RACScheduler currentScheduler] (so that they're deferred, not sent
// immediately), or they can be sent in the background. The RACDisposable
// returned by the `didSubscribe` block should cancel any such scheduling or
// asynchronous work.
//
// didSubscribe - Called when the signal is subscribed to. The new subscriber is
//                passed in. You can then manually control the <RACSubscriber> by
//                sending it -sendNext:, -sendError:, and -sendCompleted,
//                as defined by the operation you're implementing. This block
//                should return a RACDisposable which cancels any ongoing work
//                triggered by the subscription, and cleans up any resources or
//                disposables created as part of it. When the disposable is
//                disposed of, the signal must not send any more events to the
//                `subscriber`. If no cleanup is necessary, return nil.
//
// **Note:** The `didSubscribe` block is called every time a new subscriber
// subscribes. Any side effects within the block will thus execute once for each
// subscription, not necessarily on one thread, and possibly even
// simultaneously!
+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;

// Returns a signal that immediately sends the given error.
+ (RACSignal *)error:(NSError *)error;

// Returns a signal that never completes.
+ (RACSignal *)never;

// Returns a signal that calls the block in a background queue. The
// block's success is YES by default. If the block sets success = NO, the
// signal sends error with the error passed in by reference.
+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block;

// Returns a signal that calls the block with the given scheduler. The
// block's success is YES by default. If the block sets success = NO, the
// signal sends error with the error passed in by reference.
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block;

// Starts and returns an async signal. It calls the block with the given
// scheduler and gives the block the subject that was returned from the method.
// The block can send events using the subject.
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block;

@end

@interface RACSignal (RACStream)

// Returns a signal that immediately sends the given value and then completes.
+ (RACSignal *)return:(id)value;

// Returns a signal that immediately completes.
+ (RACSignal *)empty;

// Subscribes to `signal` when the source signal completes.
- (RACSignal *)concat:(RACSignal *)signal;

// Combine values from each of the signals using `reduceBlock`.
//
// `reduceBlock` will be called with the first `next` of each signal, then with
// the second `next` of each signal, and so forth. If any of the signals sent
// `complete` or `error` after the nth `next`, then the resulting signal will
// also complete or error after the nth `next`.
//
// signals     - The signals to combine. If the collection is empty, the
//               returned signal will immediately complete upon subscription.
// reduceBlock - The block which reduces the latest values from all the signals
//               into one value. It should take as many arguments as the number
//               of signals given. Each argument will be an object argument,
//               wrapped as needed. If nil, the returned signal will send a
//               RACTuple of all the latest values.
+ (RACSignal *)zip:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock;

@end

@interface RACSignal (Subscription)

// Subscribes `subscriber` to changes on the receiver. The receiver defines which
// events it actually sends and in what situations the events are sent.
//
// Subscription will always happen on a valid RACScheduler. If the
// +[RACScheduler currentScheduler] cannot be determined at the time of
// subscription (e.g., because the calling code is running on a GCD queue or
// NSOperationQueue), subscription will occur on a private background scheduler.
// On the main thread, subscriptions will always occur immediately, with a
// +[RACScheduler currentScheduler] of +[RACScheduler mainThreadScheduler].
//
// Returns nil or a disposable. You can call -[RACDisposable dispose] if you
// need to end your subscription before it would "naturally" end, either by
// completing or erroring. Once the disposable has been disposed, the subscriber
// won't receive any more events from the subscription.
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber;

// Convenience method to subscribe to the `next` event.
//
// This corresponds to `IObserver<T>.OnNext` in Rx.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock;

// Convenience method to subscribe to the `next` and `completed` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to the `next`, `completed`, and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to `error` events.
//
// This corresponds to the `IObserver<T>.OnError` in Rx.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `completed` events.
//
// This corresponds to the `IObserver<T>.OnCompleted` in Rx.
- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock;

// Convenience method to subscribe to `next` and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `error` and `completed` events.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

@end

@interface RACSignal (Debugging)

// Logs all events that the receiver sends.
//
// This method should only be used for debugging.
- (RACSignal *)logAll;

// Logs each `next` that the receiver sends.
//
// This method should only be used for debugging.
- (RACSignal *)logNext;

// Logs any error that the receiver sends.
//
// This method should only be used for debugging.
- (RACSignal *)logError;

// Logs any `completed` event that the receiver sends.
//
// This method should only be used for debugging.
- (RACSignal *)logCompleted;

@end
