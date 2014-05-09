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
///
/// `RACSignal` is an opaque class, and is not meant to be subclassed outside of
/// the framework itself.
@interface RACSignal : RACStream

#pragma clang diagnostic pop

/// Creates a new signal. This is the preferred way to create a new signal
/// operation or behavior.
///
/// didSubscribe - A block to invoke **each time** the created signal is subscribed
///                to. A new <RACSubscriber> object is created for the new
///                subscription and passed into the block.
///
///                You can manually control the <RACSubscriber> by sending it
///                -sendNext:, -sendError:, and -sendCompleted, as defined by
///                the operation you're implementing.
///
///                This block should add a RACDisposable to
///                `subscriber.disposable`, or watch the `disposed` flag on
///                `subscriber.disposable`, to cancel any ongoing work triggered
///                by the subscription, and clean up any resources or
///                disposables created as part of it.
///
///                You can also attach the subscriber to _other_ signals
///                (using -subscribe:) in this block. You do not need to save
///                the disposable returned from -subscribe: in this case, as the
///                <RACSubscriber> will automatically receive it and dispose of
///                it when appropriate.
///
///                **Note:** Any side effects within this block will execute
///                once for _each_ subscription, not necessarily on one thread,
///                and possibly even concurrently!
+ (RACSignal *)create:(void (^)(id<RACSubscriber> subscriber))didSubscribe;

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

/// Creates a subscription to the receiver, then starts it, triggering any work
/// and side effects involved in the signal.
///
/// subscriber - The subscriber to send events to. This may be nil if you don't
///              care about the events, and only wish to perform the side
///              effects of subscription.
///
/// Returns a disposable. You can call -[RACDisposable dispose] if you need to
/// cancel your subscription before it would "naturally" end, either by completing
/// or erroring. Once the disposable has been disposed, the subscriber won't
/// receive any more events from this subscription.
- (RACDisposable *)startSubscriptionWithSubscriber:(id<RACSubscriber>)subscriber;

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

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe RACDeprecated("Use +create: instead");
+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block RACDeprecated("Use +create: instead");
+ (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block RACDeprecated("Use +create: instead");

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");
- (void)subscribeSavingDisposable:(void (^)(RACDisposable *disposable))saveDisposableBlock next:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock RACDeprecated("Use -startSubscriptionWithSubscriber: instead");

@end

@interface RACSignal (Unavailable)

+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block __attribute__((unavailable("Use +create: instead")));
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block __attribute__((unavailable("Use +create: instead")));
+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block __attribute__((unavailable("Use +create: instead")));

@end
