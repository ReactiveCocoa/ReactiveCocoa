//
//  RACSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"
#import "RACStream.h"

@class RACDisposable;
@class RACScheduler;
@class RACSubject;
@protocol RACSubscriber;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

/// Represents a push-driven stream of events.
/// 
/// Signals generally represent data that will be delivered in the future. As work
/// is performed or data is received, values are _sent_ on the signal, which pushes
/// them out to any subscribers. Users must subscribe to a signal, through
/// a method like -subscribeNext:error:completed:, in order to access its values.
/// 
/// Signals send three different types of events to their subscribers:
/// 
///  * The **next** event provides a new value from the stream. Unlike Cocoa
///    collections, it is completely valid for a signal to include `nil` in its
///    values.
///  * The **error** event indicates that an error occurred before the signal could
///    finish. The event may include an `NSError` object that indicates what went
///    wrong. Errors must be handled specially – they are not included in the
///    stream's values.
///  * The **completed** event indicates that the signal finished successfully, and
///    that no more values will be added to the stream. Completion must be handled
///    specially – it is not included in the stream of values.
/// 
/// The lifetime of a signal consists of any number of `next` events, followed by
/// one `error` or `completed` event (but not both).
@interface RACSignal : RACStream

#pragma clang diagnostic pop

/// Creates a new signal. This is the preferred way to create a new signal
/// operation or behavior.
///
/// Events can be sent to new subscribers immediately in the `didSubscribe`
/// block, but the subscriber will not be able to dispose of the signal until
/// a RACDisposable is returned from `didSubscribe`. In the case of infinite
/// signals, this won't _ever_ happen if events are sent immediately.
///
/// To ensure that the signal is disposable, events can be scheduled on the
/// +[RACScheduler currentScheduler] (so that they're deferred, not sent
/// immediately), or they can be sent in the background. The RACDisposable
/// returned by the `didSubscribe` block should cancel any such scheduling or
/// asynchronous work.
///
/// didSubscribe - Called when the signal is subscribed to. The new subscriber is
///                passed in. You can then manually control the <RACSubscriber> by
///                sending it -sendNext:, -sendError:, and -sendCompleted,
///                as defined by the operation you're implementing. This block
///                should return a RACDisposable which cancels any ongoing work
///                triggered by the subscription, and cleans up any resources or
///                disposables created as part of it. When the disposable is
///                disposed of, the signal must not send any more events to the
///                `subscriber`. If no cleanup is necessary, return nil.
///
/// **Note:** The `didSubscribe` block is called every time a new subscriber
/// subscribes. Any side effects within the block will thus execute once for each
/// subscription, not necessarily on one thread, and possibly even
/// simultaneously!
+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;

/// Returns a signal that immediately sends the given error.
+ (RACSignal *)error:(NSError *)error;

/// Returns a signal that never completes.
+ (RACSignal *)never;

/// Returns a signal that immediately sends the given value and then completes.
+ (RACSignal *)return:(id)value;

/// Returns a signal that immediately completes.
+ (RACSignal *)empty;

@end

@interface RACSignal (Subscription)

/// Subscribes `subscriber` to changes on the receiver. The receiver defines which
/// events it actually sends and in what situations the events are sent.
///
/// Subscription will always happen on a valid RACScheduler. If the
/// +[RACScheduler currentScheduler] cannot be determined at the time of
/// subscription (e.g., because the calling code is running on a GCD queue or
/// NSOperationQueue), subscription will occur on a private background scheduler.
/// On the main thread, subscriptions will always occur immediately, with a
/// +[RACScheduler currentScheduler] of +[RACScheduler mainThreadScheduler].
///
/// This method must be overridden by any subclasses.
///
/// Returns nil or a disposable. You can call -[RACDisposable dispose] if you
/// need to end your subscription before it would "naturally" end, either by
/// completing or erroring. Once the disposable has been disposed, the subscriber
/// won't receive any more events from the subscription.
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber;

/// Convenience method to subscribe to the `next` event.
///
/// This corresponds to `IObserver<T>.OnNext` in Rx.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock;

/// Convenience method to subscribe to the `next` and `completed` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

/// Convenience method to subscribe to the `next`, `completed`, and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

/// Convenience method to subscribe to `error` events.
///
/// This corresponds to the `IObserver<T>.OnError` in Rx.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock;

/// Convenience method to subscribe to `completed` events.
///
/// This corresponds to the `IObserver<T>.OnCompleted` in Rx.
- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock;

/// Convenience method to subscribe to `next` and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock;

/// Convenience method to subscribe to `error` and `completed` events.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

@end

/// Additional methods to assist with debugging.
@interface RACSignal (Debugging)

/// The name of the signal. This is for debugging/human purposes only.
@property (copy) NSString *name;

/// Sets the name of the receiver to the given format string.
///
/// This is for debugging purposes only, and won't do anything unless the DEBUG
/// preprocessor macro is defined.
///
/// Returns the receiver, for easy method chaining.
- (instancetype)setNameWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/// Logs all events that the receiver sends.
- (RACSignal *)logAll;

/// Logs each `next` that the receiver sends.
- (RACSignal *)logNext;

/// Logs any error that the receiver sends.
- (RACSignal *)logError;

/// Logs any `completed` event that the receiver sends.
- (RACSignal *)logCompleted;

@end

/// Additional methods to assist with unit testing.
///
/// **These methods should never ship in production code.**
@interface RACSignal (Testing)

/// Spins the main run loop for a short while, waiting for the receiver to send a `next`.
///
/// **Because this method executes the run loop recursively, it should only be used
/// on the main thread, and only from a unit test.**
///
/// defaultValue - Returned if the receiver completes or errors before sending
///                a `next`, or if the method times out. This argument may be
///                nil.
/// success      - If not NULL, set to whether the receiver completed
///                successfully.
/// error        - If not NULL, set to any error that occurred.
///
/// Returns the first value received, or `defaultValue` if no value is received
/// before the signal finishes or the method times out.
- (id)asynchronousFirstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error;

/// Spins the main run loop for a short while, waiting for the receiver to complete.
///
/// **Because this method executes the run loop recursively, it should only be used
/// on the main thread, and only from a unit test.**
///
/// error - If not NULL, set to any error that occurs.
///
/// Returns whether the signal completed successfully before timing out. If NO,
/// `error` will be set to any error that occurred.
- (BOOL)asynchronouslyWaitUntilCompleted:(NSError **)error;

@end

@interface RACSignal (Deprecated)

+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block RACDeprecated("Use RACPromise instead");
+ (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block RACDeprecated("Use RACPromise instead");

@end

@interface RACSignal (Unavailable)

+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block __attribute__((unavailable("Use RACPromise instead")));
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block __attribute__((unavailable("Use RACPromise instead")));
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block __attribute__((unavailable("Use RACPromise instead")));

@end
