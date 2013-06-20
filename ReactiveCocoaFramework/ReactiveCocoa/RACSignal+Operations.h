//
//  RACSignal+Operations.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/RACSignal.h>

// The domain for errors originating in RACSignal operations.
extern NSString * const RACSignalErrorDomain;

// The error code used with -timeout:.
extern const NSInteger RACSignalErrorTimedOut;

@class RACMulticastConnection;
@class RACDisposable;
@class RACScheduler;
@class RACSequence;
@class RACSubject;
@class RACTuple;
@class RACCommand;
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

// Send `next`s only if we don't receive another `next` in `interval` seconds.
//
// If a `next` is received, and then another `next` is received before
// `interval` seconds have passed, the first value is discarded.
//
// After `interval` seconds have passed since the most recent `next` was sent,
// the most recent `next` is forwarded on the scheduler that the value was
// originally received on. If +[RACScheduler currentScheduler] was nil at the
// time, a private background scheduler is used.
//
// Returns a signal which sends throttled and delayed `next` events. Completion
// and errors are always forwarded immediately.
- (RACSignal *)throttle:(NSTimeInterval)interval;

// Throttles `next`s for which `predicate` returns YES.
//
// When `predicate` returns YES for a `next`:
//
//  1. If another `next` is received before `interval` seconds have passed, the
//     prior value is discarded. This happens regardless of whether the new
//     value will be throttled.
//  2. After `interval` seconds have passed since the value was originally
//     received, it will be forwarded on the scheduler that it was received
//     upon. If +[RACScheduler currentScheduler] was nil at the time, a private
//     background scheduler is used.
//
// When `predicate` returns NO for a `next`, it is forwarded immediately,
// without any throttling.
//
// interval  - The number of seconds for which to buffer the latest value that
//             passes `predicate`.
// predicate - Passed each `next` from the receiver, this block returns
//             whether the given value should be throttled. This argument must
//             not be nil.
//
// Returns a signal which sends `next` events, throttled when `predicate`
// returns YES. Completion and errors are always forwarded immediately.
- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate;

// Forwards `next` and `completed` events after delaying for `interval` seconds
// on the current scheduler (on which the events were delivered).
//
// If +[RACScheduler currentScheduler] is nil when `next` or `completed` is
// received, a private background scheduler is used.
//
// Returns a signal which sends delayed `next` and `completed` events. Errors
// are always forwarded immediately.
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

// Collect all receiver's `next`s into a NSArray. nil values will be converted
// to NSNull.
//
// This corresponds to the `ToArray` method in Rx.
//
// Returns a signal which sends a single NSArray when the receiver completes
// successfully.
- (RACSignal *)collect;

// Takes the last `count` `next`s after the receiving signal completes.
- (RACSignal *)takeLast:(NSUInteger)count;

// Combines the latest values from the receiver and the given signal into
// RACTuples, once both have sent at least one `next`.
//
// Any additional `next`s will result in a new RACTuple with the latest values
// from both signals.
//
// signal - The signal to combine with. This argument must not be nil.
//
// Returns a signal which sends RACTuples of the combined values, forwards any
// `error` events, and completes when both input signals complete. If either
// input signal is empty, the returned signal will complete immediately.
- (RACSignal *)combineLatestWith:(RACSignal *)signal;

// Combines the latest values from the given signals into RACTuples, once all
// the signals have sent at least one `next`.
//
// Any additional `next`s will result in a new RACTuple with the latest values
// from all signals.
//
// signals - The signals to combine. If this collection is empty, the returned
//           signal will immediately complete upon subscription.
//
// Returns a signal which sends RACTuples of the combined values, forwards any
// `error` events, and completes when all input signals complete. If any input
// signal is empty, the returned signal will complete immediately.
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals;

// Combines signals using +combineLatest:, then reduces the resulting tuples
// into a single value using -reduceEach:.
//
// signals     - The signals to combine. If this collection is empty, the
//               returned signal will immediately complete upon subscription.
// reduceBlock - The block which reduces the latest values from all the
//               signals into one value. It should take as many arguments as the
//               number of signals given. Each argument will be an object
//               argument. This argument must not be nil.
//
// Example:
//
//   [RACSignal combineLatest:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
//       return [NSString stringWithFormat:@"%@: %@", string, number];
//   }];
//
// Returns a signal which sends the results from each invocation of
// `reduceBlock`.
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock;

// Sends the latest `next` from any of the signals.
//
// Returns a signal that passes through values from each of the given signals,
// and sends `completed` when all of them complete. If any signal sends an error,
// the returned signal sends `error` immediately.
+ (RACSignal *)merge:(id<NSFastEnumeration>)signals;

// Merges the signals sent by the receiver into a flattened signal, but only
// subscribes to `maxConcurrent` number of signals at a time. New signals are
// queued and subscribed to as other signals complete.
//
// If an error occurs on any of the signals, it is sent on the returned signal.
// It completes only after the receiver and all sent signals have completed.
//
// This corresponds to `Merge<TSource>(IObservable<IObservable<TSource>>, Int32)`
// in Rx.
//
// maxConcurrent - the maximum number of signals to subscribe to at a
//                 time. If 0, it subscribes to an unlimited number of
//                 signals.
- (RACSignal *)flatten:(NSUInteger)maxConcurrent;

// Ignores all `next`s from the receiver, and after the receiver completes, gets
// a new signal to subscribe to.
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
// A given object property should only have one active signal bound to it at any
// given time. Binding more than one signal to the same property is considered
// undefined behavior.
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
// Returns a signal that sends the current date/time every `interval` on the
// global concurrent high priority queue.
+ (RACSignal *)interval:(NSTimeInterval)interval;

// Sends NSDate.date at intervals of at least `interval` seconds, up to
// approximately `interval` + `leeway` seconds.
//
// The created signal will defer sending each `next` for at least `interval`
// seconds, and for an additional amount of time up to `leeway` seconds in the
// interest of performance or power consumption. Note that some additional
// latency is to be expected, even when specifying a `leeway` of 0.
//
// interval - The base interval between `next`s.
// leeway   - The maximum amount of additional time the `next` can be deferred.
//
// Returns a signal that sends the current date/time at intervals of at least
// `interval seconds` up to approximately `interval` + `leeway` seconds on the
// global concurrent high priority queue.
+ (RACSignal *)interval:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway;

// Take `next`s until the `signalTrigger` sends `next` or `completed`.
//
// Returns a signal which passes through all events from the receiver until
// `signalTrigger` sends `next` or `completed`, at which point the returned signal
// will send `completed`.
- (RACSignal *)takeUntil:(RACSignal *)signalTrigger;

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

// Blocks the caller and waits for the signal to complete.
//
// error - If not NULL, set to any error that occurs.
//
// Returns whether the signal completed successfully. If NO, `error` will be set
// to the error that occurred.
- (BOOL)waitUntilCompleted:(NSError **)error;

// Defer creation of a signal until the signal's actually subscribed to.
//
// This can be used to effectively turn a hot signal into a cold signal.
+ (RACSignal *)defer:(RACSignal * (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the
// previous `next`.
- (RACSignal *)distinctUntilChanged;

// Every time the receiver sends a new RACSignal, subscribes and sends `next`s and
// `error`s only for that signal.
//
// The receiver must be a signal of signals.
//
// Returns a signal which passes through `next`s and `error`s from the latest
// signal sent by the receiver, and sends `completed` when the receiver completes.
- (RACSignal *)switchToLatest;

// Switches between `trueSignal` and `falseSignal` based on the latest value
// sent by `boolSignal`.
//
// boolSignal  - A signal of BOOLs determining whether `trueSignal` or
//               `falseSignal` should be active. This argument must not be nil.
// trueSignal  - The signal to pass through after `boolSignal` has sent YES.
//               This argument must not be nil.
// falseSignal - The signal to pass through after `boolSignal` has sent NO. This
//               argument must not be nil.
//
// Returns a signal which passes through `next`s and `error`s from `trueSignal`
// and/or `falseSignal`, and sends `completed` when `boolSignal` completes.
+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal;

// Add every `next` to an array. Nils are represented by NSNulls. Note that this
// is a blocking call.
//
// **This is not the same as the `ToArray` method in Rx.** See -collect for
// that behavior instead.
//
// Returns the array of `next` values, or nil if an error occurs.
- (NSArray *)toArray;

// Add every `next` to a sequence. Nils are represented by NSNulls.
//
// This corresponds to the `ToEnumerable` method in Rx.
//
// Returns a sequence which provides values from the signal as they're sent.
// Trying to retrieve a value from the sequence which has not yet been sent will
// block.
@property (nonatomic, strong, readonly) RACSequence *sequence;

// Creates and returns a multicast connection. This allows you to share a single
// subscription to the underlying signal.
- (RACMulticastConnection *)publish;

// Creates and returns a multicast connection that pushes values into the given
// subject. This allows you to share a single subscription to the underlying
// signal.
- (RACMulticastConnection *)multicast:(RACSubject *)subject;

// Multicasts the signal to a RACReplaySubject of unlimited capacity, and
// immediately connects to the resulting RACMulticastConnection.
//
// Returns the connected, multicasted signal.
- (RACSignal *)replay;

// Multicasts the signal to a RACReplaySubject of capacity 1, and immediately
// connects to the resulting RACMulticastConnection.
//
// Returns the connected, multicasted signal.
- (RACSignal *)replayLast;

// Multicasts the signal to a RACReplaySubject of unlimited capacity, and calls
// -autoconnect on the resulting RACMulticastConnection.
//
// This means the returned signal will subscribe to the multicasted signal only
// when the former receives its first subscription.
//
// Returns the autoconnected, multicasted signal.
- (RACSignal *)replayLazily;

// Sends an error after `interval` seconds if the source doesn't complete
// before then.
//
// The error will be in the RACSignalErrorDomain and have a code of
// RACSignalErrorTimedOut.
//
// Returns a signal that passes through the receiver's events on an
// indeterminate scheduler, until the stream finishes or times out.
- (RACSignal *)timeout:(NSTimeInterval)interval;

// Creates and returns a signal that delivers its events on the given scheduler.
// Any side effects of the receiver will still be performed on the original
// thread.
//
// This is ideal when the signal already performs its work on the desired
// thread, but you want to handle its events elsewhere.
//
// This corresponds to the `ObserveOn` method in Rx.
- (RACSignal *)deliverOn:(RACScheduler *)scheduler;

// Creates and returns a signal that executes its side effects and delivers its
// events on the given scheduler.
//
// Use of this operator should be avoided whenever possible, because the
// receiver's side effects may not be safe to run on another thread. If you just
// want to receive the signal's events on `scheduler`, use -deliverOn: instead.
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

// Sends the latest value from the receiver only when `sampler` sends a value.
// The returned signal could repeat values if `sampler` fires more often than
// the receiver.
//
// sampler - The signal that controls when the latest value from the receiver
//           is sent. Cannot be nil.
- (RACSignal *)sample:(RACSignal *)sampler;

// Ignores all `next`s from the receiver.
//
// Returns a signal which only passes through `error` or `completed` events from
// the receiver.
- (RACSignal *)ignoreElements;

// Converts each of the receiver's events into a RACEvent object.
//
// Returns a signal which sends the receiver's events as RACEvents, and
// completes after the receiver sends `completed` or `error`.
- (RACSignal *)materialize;

// Converts each RACEvent in the receiver back into "real" RACSignal events.
//
// Returns a signal which sends `next` for each value RACEvent, `error` for each
// error RACEvent, and `completed` for each completed RACEvent.
- (RACSignal *)dematerialize;

// Inverts each NSNumber-wrapped BOOL sent by the receiver. It will assert if
// the receiver sends anything other than NSNumbers.
//
// Returns a signal of inverted NSNumber-wrapped BOOLs.
- (RACSignal *)not;

// Subscribes to the receiver and executes the command with each `next`.
//
// This can be useful when you want to execute a command based off a signal:
//
//   [[textField.rac_textSignal throttle:0.3] executeCommand:searchCommand];
//
// command - The command to execute. Cannot be nil.
//
// Returns the disposable for the underlying subscription.
- (RACDisposable *)executeCommand:(RACCommand *)command;

@end
