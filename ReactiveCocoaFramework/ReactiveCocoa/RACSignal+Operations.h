//
//  RACSignal+Operations.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSignal.h"

extern NSString * const RACSignalErrorDomain;

typedef enum {
	// The error code used with -timeout:.
	RACSignalErrorTimedOut = 1,
} _RACSignalError;

typedef NSInteger RACSignalError;

@class RACCancelableSignal;
@class RACConnectableSignal;
@class RACDisposable;
@class RACScheduler;
@class RACSequence;
@class RACSubject;
@class RACTuple;
@protocol RACSubscriber;

@interface RACSignal (Operations)

// Do the given block on `next`. This should be used to inject side effects into
// the signal.
- (RACSignal *)doNext:(void (^)(id x))block;

// Do the given block on `error`. This should be used to inject side effects
// into the signal.
- (RACSignal *)doError:(void (^)(NSError *error))block;

// Do the given block on `completed`. This should be used to inject side effects
// into the signal.
- (RACSignal *)doCompleted:(void (^)(void))block;

// Only send `next` when we don't receive another `next` in `interval` seconds.
- (RACSignal *)throttle:(NSTimeInterval)interval;

// Sends `next` after delaying for `interval` seconds.
- (RACSignal *)delay:(NSTimeInterval)interval;

// Resubscribes when the signal completes.
- (RACSignal *)repeat;

// Execute the given block when the signal completes or errors.
- (RACSignal *)finally:(void (^)(void))block;

// Divide the `next`s of the signal into windows. When `openSignal` sends a
// next, a window is opened and the `closeBlock` is asked for a close
// signal. The window is closed when the close signal sends a `next`.
- (RACSignal *)windowWithStart:(RACSignal *)openSignal close:(RACSignal * (^)(RACSignal *start))closeBlock;

// Divide the `next`s into buffers with `bufferCount` items each. The `next`
// will be a RACTuple of values.
- (RACSignal *)buffer:(NSUInteger)bufferCount;

// Divide the `next`s into buffers delivery every `interval` seconds. The `next`
// will be a RACTuple of values.
- (RACSignal *)bufferWithTime:(NSTimeInterval)interval;

// Collect all receiver's `next`s into a NSArray.
//
// Returns a signal which sends a single NSArray when the receiver completes.
- (RACSignal *)collect;

// Takes the last `count` `next`s after the receiving signal completes.
- (RACSignal *)takeLast:(NSUInteger)count;

// Invokes +combineLatest:reduce: with a nil `reduceBlock`.
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals;

// Combine the latest values from each of the signals once all the signals have
// sent a `next`. Any additional `next`s will result in a new reduced value
// based on all the latest values from all the signals.
//
// The `next` of the returned signal will be the return value of the
// `reduceBlock`.
//
// signals     - The signals to combine. If empty or `nil`, the returned signal
//               will immediately complete upon subscription.
// reduceBlock - The block which reduces the latest values from all the
//               signals into one value. It should take as many arguments as the
//               number of signals given. Each argument will be an object
//               argument, wrapped as needed. If nil, the returned signal will
//               send a RACTuple of all the latest values.
//
// Example:
//   [RACSignal combineLatest:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *wrappedInt) {
//       return [NSString stringWithFormat:@"%@: %@", string, wrappedInt];
//   }];
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock;

// Sends the latest `next` from any of the signals.
+ (RACSignal *)merge:(id<NSFastEnumeration>)signals;

// Merges the signals sent by the receiver into a flattened signal, but only
// subscribes to `maxConcurrent` number of signals at a time. New signals are
// queued and subscribed to as other signals complete.
//
// If an error occurs on any of the signals, it is sent on the returned signal.
// It completes only after the receiver and all sent signals have completed.
//
// maxConcurrent - the maximum number of signals to subscribe to at a
//                 time. If 0, it subscribes to an unlimited number of
//                 signals.
- (RACSignal *)flatten:(NSUInteger)maxConcurrent;

// Gets a new signal to subscribe to after the receiver completes.
- (RACSignal *)sequenceNext:(RACSignal * (^)(void))block;

// Concats the inner signals of a signal of signals.
- (RACSignal *)concat;

// Aggregate `next`s with the given start and combination.
- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Aggregate `next`s with the given start and combination. The start factory 
// block is called to get a new start object for each subscription.
- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock;

// Binds the receiver to an object, automatically setting the given key path on
// every `next`. When the signal completes, the binding is automatically
// disposed of.
//
// Sending an error on the signal is considered undefined behavior, and will
// generate an assertion failure in Debug builds.
//
// keyPath - The key path to update with `next`s from the receiver.
// object  - The object that `keyPath` is relative to.
//
// Returns a disposable which can be used to terminate the binding.
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object;

// Sends NSDate.date every `interval` seconds.
//
// interval - The time interval in seconds at which the current time is sent.
//
// Returns a signal that sends the current date/time every `interval`.
+ (RACSignal *)interval:(NSTimeInterval)interval;

// Take `next`s until the `signalTrigger` sends a `next`.
- (RACSignal *)takeUntil:(RACSignal *)signalTrigger;

// Convert every `next` and `error` into a RACMaybe.
- (RACSignal *)asMaybes;

// Subscribe to the returned signal when an error occurs.
- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock;

// Subscribe to the given signal when an error occurs.
- (RACSignal *)catchTo:(RACSignal *)signal;

// Returns the first `next`. Note that this is a blocking call.
- (id)first;

// Returns the first `next` or `defaultValue` if the signal completes or errors
// without sending a `next`. Note that this is a blocking call.
- (id)firstOrDefault:(id)defaultValue;

// Returns the first `next` or `defaultValue` if the signal completes or errors
// without sending a `next`. If an error occurs success will be NO and error
// will be populated. Note that this is a blocking call.
//
// Both success and error may be NULL.
- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error;

// Defer creation of a signal until the signal's actually subscribed to.
//
// This can be used to effectively turn a hot signal into a cold signal.
+ (RACSignal *)defer:(RACSignal * (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the
// previous `next`.
- (RACSignal *)distinctUntilChanged;

// The source must be a signal of signals. Subscribe and send `next`s for the
// latest signal. This is mostly useful when combined with `-flattenMap:`.
- (RACSignal *)switch;

// Add every `next` to an array. Nils are represented by NSNulls. Note that this
// is a blocking call.
- (NSArray *)toArray;

// Add every `next` to a sequence. Nils are represented by NSNulls.
//
// Returns a sequence which provides values from the signal as they're sent.
// Trying to retrieve a value from the sequence which has not yet been sent will
// block.
@property (nonatomic, strong, readonly) RACSequence *sequence;

// Creates and returns a connectable signal. This allows you to share a single
// subscription to the underlying signal.
- (RACConnectableSignal *)publish;

// Creates and returns a connectable signal that pushes values into the given
// subject. This allows you to share a single subscription to the underlying
// signal.
- (RACConnectableSignal *)multicast:(RACSubject *)subject;

// Sends an error after `interval` seconds if the source doesn't complete
// before then. The timeout is scheduled on the default priority global queue.
- (RACSignal *)timeout:(NSTimeInterval)interval;

// Creates and returns a signal that delivers its callbacks using the given
// scheduler.
- (RACSignal *)deliverOn:(RACScheduler *)scheduler;

// Creates and returns a signal whose `didSubscribe` block is scheduled with the
// given scheduler.
- (RACSignal *)subscribeOn:(RACScheduler *)scheduler;

// Creates a shared signal which is passed into the let block. The let block
// then returns a signal derived from that shared signal.
- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock;

// Groups each received object into a group, as determined by calling `keyBlock`
// with that object. The object sent is transformed by calling `transformBlock`
// with the object. If `transformBlock` is nil, it sends the original object.
//
// The returned signal is a signal of RACGroupedSignal.
- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock;

// Calls -[RACSignal groupBy:keyBlock transform:nil].
- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock;

// Sends an [NSNumber numberWithBool:YES] if the receiving signal sends any
// objects.
- (RACSignal *)any;

// Sends an [NSNumber numberWithBool:YES] if the receiving signal sends any
// objects that pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (RACSignal *)any:(BOOL (^)(id object))predicateBlock;

// Sends an [NSNumber numberWithBool:YES] if all the objects the receiving 
// signal sends pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (RACSignal *)all:(BOOL (^)(id object))predicateBlock;

// Resubscribes to the receiving signal if an error occurs, up until it has
// retried the given number of times.
//
// retryCount - if 0, it keeps retrying until it completes.
- (RACSignal *)retry:(NSInteger)retryCount;

// Resubscribes to the receiving signal if an error occurs.
- (RACSignal *)retry;

// Creates a cancelable signal multicasted to the given subject with the given
// cancelation block.
- (RACCancelableSignal *)asCancelableToSubject:(RACSubject *)subject withBlock:(void (^)(void))block;

// Creates a cancelable signal with the given cancelation block.
- (RACCancelableSignal *)asCancelableWithBlock:(void (^)(void))block;

// Creates a cancelable signal.
- (RACCancelableSignal *)asCancelable;

// Sends the latest value from the receiver only when `sampler` sends a value.
// The returned signal could repeat values if `sampler` fires more often than
// the receiver.
//
// sampler - The signal that controls when the latest value from the receiver
//           is sent. Cannot be nil.
- (RACSignal *)sample:(RACSignal *)sampler;

@end
