//
//  RACSignal+Operations.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"
#import "RACSignal.h"

/// The domain for errors originating in RACSignal operations.
extern NSString * const RACSignalErrorDomain;

/// The error code used with -timeout:.
extern const NSInteger RACSignalErrorTimedOut;

/// The error code used when a value passed into +switch:cases:default: does not
/// match any of the cases, and no default was given.
extern const NSInteger RACSignalErrorNoMatchingCase;

/// A block which accepts a value from a RACSignal and returns a new signal.
///
/// Setting `stop` to `YES` will cause the bind to terminate after the returned
/// value. Returning `nil` will result in immediate termination.
typedef RACSignal * (^RACSignalBindBlock)(id value, BOOL *stop);

/// The policy that -flatten:withPolicy: should follow when additional signals
/// arrive while `maxConcurrent` signals are already subscribed to.
///
/// RACSignalFlattenPolicyQueue           - Wait until any current signal
///                                         completes, then subscribe to the
///                                         additional (enqueued) signal that
///                                         arrived earliest.
/// RACSignalFlattenPolicyDisposeEarliest - Dispose of the active subscription
///                                         to the signal that arrived earliest,
///                                         then subscribe to the new signal.
/// RACSignalFlattenPolicyDisposeLatest   - Dispose of the active subscription
///                                         to the signal that arrived latest,
///                                         then subscribe to the new signal.
typedef enum : NSUInteger {
	RACSignalFlattenPolicyQueue,
	RACSignalFlattenPolicyDisposeEarliest,
	RACSignalFlattenPolicyDisposeLatest
} RACSignalFlattenPolicy;

@class RACCommand;
@class RACDisposable;
@class RACMulticastConnection;
@class RACScheduler;
@class RACSequence;
@class RACSubject;
@class RACTuple;
@protocol RACSubscriber;

@interface RACSignal (Operations)

/// Subscribes to `signal` when the source signal completes.
- (RACSignal *)concat:(RACSignal *)signal;

/// Maps `block` across the values in the receiver and flattens the result.
///
/// Note that operators applied _after_ -flattenMap: behave differently from
/// operators _within_ -flattenMap:. See the Examples section below.
///
/// This corresponds to the `SelectMany` method in Rx.
///
/// block - A block which accepts the values in the receiver and returns a new
///         signal. Returning `nil` from this block is equivalent to returning
///         an empty signal.
///
/// Examples
///
///   [signal flattenMap:^(id x) {
///       // Logs each time a returned signal completes.
///       return [[RACSignal return:x] logCompleted];
///   }];
///
///   [[signal
///       flattenMap:^(id x) {
///           return [RACSignal return:x];
///       }]
///       // Logs only once, when all of the signals complete.
///       logCompleted];
///
/// Returns a new signal which represents the combination of all signals
/// returned from `block`. The resulting signal will forward events from all of
/// the original signals in the order that they arrive.
- (RACSignal *)flattenMap:(RACSignal * (^)(id value))block;

/// Flattens a signal of signals.
///
/// This corresponds to the `Merge` method in Rx.
///
/// Returns a signal which represents the combination of all signals sent by the
/// receiver. The resulting signal will forward events from all of the original
/// signals in the order that they arrive.
- (RACSignal *)flatten;

/// Maps `block` across the values in the receiver.
///
/// This corresponds to the `Select` method in Rx.
///
/// Returns a new signal with the mapped values.
- (RACSignal *)map:(id (^)(id value))block;

/// Replace each value in the receiver with the given object.
///
/// Returns a new signal which includes the given object once for each value in
/// the receiver.
- (RACSignal *)mapReplace:(id)object;

/// Filters out values in the receiver that don't pass the given test.
///
/// This corresponds to the `Where` method in Rx.
///
/// Returns a new signal with only those values that passed.
- (RACSignal *)filter:(BOOL (^)(id value))block;

/// Filters out values in the receiver that equal (via -isEqual:) the provided value.
///
/// value - The value can be `nil`, in which case it ignores `nil` values.
///
/// Returns a new signal containing only the values which did not compare equal
/// to `value`.
- (RACSignal *)ignore:(id)value;

/// Unpacks each RACTuple in the receiver and maps the values to a new value.
///
/// reduceBlock - The block which reduces each RACTuple's values into one value.
///               It must take as many arguments as the number of tuple elements
///               to process. Each argument will be an object argument. The
///               return value must be an object. This argument cannot be nil.
///
/// Returns a signal which will send the return values from `reduceBlock`.
- (RACSignal *)reduceEach:(id (^)())reduceBlock;

/// Returns a new signal consisting of `value`, followed by the values in the
/// receiver.
- (RACSignal *)startWith:(id)value;

/// Skips the first `skipCount` values in the receiver.
///
/// Returns the receiver after skipping the first `skipCount` values. If
/// `skipCount` is greater than the number of values in the signal, the
/// resulting signal will complete immediately.
- (RACSignal *)skip:(NSUInteger)skipCount;

/// Returns a signal of the first `count` values in the receiver. If `count` is
/// greater than or equal to the number of values in the signal, a signal
/// equivalent to the receiver is returned.
- (RACSignal *)take:(NSUInteger)count;

/// Zips the values in the receiver with those of the given signal to create
/// RACTuples.
///
/// The first `next` of each signal will be combined, then the second `next`, and
/// so forth, until either signal completes or errors.
///
/// signal - The signal to zip with. This must not be `nil`.
///
/// Returns a new signal of RACTuples, representing the combined values of the
/// two signals. Any error from one of the original signals will be forwarded on
/// the returned signal.
- (RACSignal *)zipWith:(RACSignal *)signal;

/// Zips the values in the given signals to create RACTuples.
///
/// The first `next` of each signal will be combined, then the second `next`, and
/// so forth, until either signal completes or errors.
///
/// signals - The RACSignals to combine. If this collection is empty, the
///           returned signal will complete immediately.
///
/// Returns a new signal containing RACTuples of the zipped values from the
/// signals.
+ (RACSignal *)zip:(id<NSFastEnumeration>)signals;

/// Zips signals using +zip:, then reduces the resulting tuples into a single
/// value using -reduceEach:.
///
/// signals     - The RACSignals to combine. If this collection is empty, the
///               returned signal will complete immediately.
/// reduceBlock - The block which reduces the values from all the signals
///               into one value. It must take as many arguments as the
///               number of `signals` given. Each argument will be an object
///               argument. The return value must be an object. This argument
///               must not be nil.
///
/// Example:
///
///   [RACSignal zip:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
///       return [NSString stringWithFormat:@"%@: %@", string, number];
///   }];
///
/// Returns a new signal containing the results from each invocation of
/// `reduceBlock`.
+ (RACSignal *)zip:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock;

/// Returns a signal obtained by concatenating `signals` in order.
+ (RACSignal *)concat:(id<NSFastEnumeration>)signals;

/// Combines values in the receiver from left to right using the given block.
///
/// The algorithm proceeds as follows:
///
///  1. `start` is passed into the block as the `running` value, and the first
///     element of the receiver is passed into the block as the `next` value.
///  2. The result of the invocation is sent on the returned signal.
///  3. The result of the invocation (`running`) and the next element of the
///     receiver (`next`) is passed into `block`.
///  4. Steps 2 and 3 are repeated until all values have been processed.
///
/// This method is similar to -aggregateWithStart:reduce:, except that the
/// result of each step is sent on the returned signal.
///
/// startingValue - The value to be combined with the first element of the
///                 receiver. This value may be `nil`.
/// block         - A block that describes how to combine values of the
///                 receiver. If the receiver is empty, this block will never be
///                 invoked.
///
/// Examples
///
///      RACSequence *numbers = @[ @1, @2, @3, @4 ].rac_sequence;
///
///      // Contains 1, 3, 6, 10
///      RACSequence *sums = [numbers scanWithStart:@0 reduce:^(NSNumber *sum, NSNumber *next) {
///          return @(sum.integerValue + next.integerValue);
///      }];
///
/// Returns a signal that will send the return values from `block`. If the
/// receiver is empty, the resulting signal will complete immediately.
- (RACSignal *)scanWithStart:(id)startingValue reduce:(id (^)(id running, id next))block;

/// Combines each previous and current value into one object.
///
/// This method is similar to -scanWithStart:reduce:, but only ever operates on
/// the previous and current values (instead of the whole signal), and does not
/// pass the return value of `reduceBlock` into the next invocation of it.
///
/// start       - The value passed into `reduceBlock` as `previous` for the
///               first value.
/// reduceBlock - The block that combines the previous value and the current
///               value to create the reduced value. Cannot be nil.
///
/// Examples
///
///      RACSequence *numbers = @[ @1, @2, @3, @4 ].rac_sequence;
///
///      // Contains 1, 3, 5, 7
///      RACSequence *sums = [numbers combinePreviousWithStart:@0 reduce:^(NSNumber *previous, NSNumber *next) {
///          return @(previous.integerValue + next.integerValue);
///      }];
///
/// Returns a signal that will send the return values from `reduceBlock`. If the
/// receiver is empty, the resulting signal will complete immediately.
- (RACSignal *)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id current))reduceBlock;

/// Takes values until the given block returns `NO`.
///
/// Returns a signal of the initial values in the receiver that pass `predicate`.
/// If `predicate` never returns `NO`, a signal equivalent to the receiver is
/// returned.
- (RACSignal *)takeWhile:(BOOL (^)(id x))predicate;

/// Skips values until the given block returns `NO`.
///
/// Returns a signal containing the values of the receiver that follow any
/// initial values passing `predicate`. If `predicate` never returns `NO`, an
/// empty signal is returned.
- (RACSignal *)skipWhile:(BOOL (^)(id x))predicate;

/// Returns a signal of values for which -isEqual: returns NO when compared to the
/// previous value.
- (RACSignal *)distinctUntilChanged;

/// Run the given block before passing through a `next` event.
///
/// This should be used to inject side effects into the signal.
///
/// Returns a signal which forwards the events of the receiver, running `block`
/// before forwarding any `next`s.
- (RACSignal *)doNext:(void (^)(id x))block;

/// Run the given block before passing through an `error` event.
///
/// This should be used to inject side effects into the signal.
///
/// Returns a signal which forwards the events of the receiver, running `block`
/// before forwarding `error`.
- (RACSignal *)doError:(void (^)(NSError *error))block;

/// Run the given block before passing through an `completed` event.
///
/// This should be used to inject side effects into the signal.
///
/// Returns a signal which forwards the events of the receiver, running `block`
/// before forwarding `completed`.
- (RACSignal *)doCompleted:(void (^)(void))block;

/// Run the given block immediately when the subscription is disposed.
///
/// This should be used to inject side effects into the signal.
///
/// Note that subscriptions are automatically disposed upon `error` and
/// `completed` events, so this block will effectively run whenever the signal
/// terminates or is cancelled through _any_ means.
///
/// Use -doFinished: instead, if you don't want to perform side effects upon
/// cancellation.
///
/// Returns a signal which forwards the events of the receiver, running `block`
/// before forwarding `completed` or `error`, or immediately upon disposal.
- (RACSignal *)doDisposed:(void (^)(void))block;

/// Run the given block before passing through a `completed` or `error` event.
///
/// This should be used to inject side effects into the signal.
/// 
/// Use -doDisposed: instead, if you also want to perform side effects upon
/// cancellation.
///
/// This corresponds to the `Finally` method in Rx.
///
/// Returns a signal which forwards the events of the receiver, running `block`
/// before forwarding `completed` or `error`.
- (RACSignal *)doFinished:(void (^)(void))block;

/// Send `next`s only if we don't receive another `next` in `interval` seconds.
///
/// If a `next` is received, and then another `next` is received before
/// `interval` seconds have passed, the first value is discarded.
///
/// After `interval` seconds have passed since the most recent `next` was sent,
/// the most recent `next` is forwarded on the scheduler that the value was
/// originally received on. If +[RACScheduler currentScheduler] was nil at the
/// time, a private background scheduler is used.
///
/// Returns a signal which sends throttled and delayed `next` events. Completion
/// and errors are always forwarded immediately.
- (RACSignal *)throttleDiscardingEarliest:(NSTimeInterval)interval;

/// For every `next` sent by the receiver, forward it only if there wasn't
/// a previous value in the last `interval` seconds.
///
/// If a `next` is received, and then another `next` is received before
/// `interval` seconds have passed, the second value is discarded.
///
/// Returns a signal which sends `next` events as they're received, dropping any
/// that arrive less than `interval` seconds since the last. Completion and
/// errors are always forwarded immediately.
- (RACSignal *)throttleDiscardingLatest:(NSTimeInterval)interval;

/// Forwards `next` and `completed` events after delaying for `interval` seconds
/// on the current scheduler (on which the events were delivered).
///
/// If +[RACScheduler currentScheduler] is nil when `next` or `completed` is
/// received, a private background scheduler is used.
///
/// Returns a signal which sends delayed `next` and `completed` events. Errors
/// are always forwarded immediately.
- (RACSignal *)delay:(NSTimeInterval)interval;

/// Resubscribes when the signal completes.
- (RACSignal *)repeat;

/// Divides the receiver's `next`s into buffers which deliver every `interval`
/// seconds.
///
/// interval  - The interval in which values are grouped into one buffer.
/// scheduler - The scheduler upon which the returned signal will deliver its
///             values. This must not be nil or +[RACScheduler
///             immediateScheduler].
///
/// Returns a signal which sends RACTuples of the buffered values at each
/// interval on `scheduler`. When the receiver completes, any currently-buffered
/// values will be sent immediately.
- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;

/// Collect all receiver's `next`s into a NSArray. nil values will be converted
/// to NSNull.
///
/// This corresponds to the `ToArray` method in Rx.
///
/// Returns a signal which sends a single NSArray when the receiver completes
/// successfully.
- (RACSignal *)collect;

/// Takes the last `count` `next`s after the receiving signal completes.
- (RACSignal *)takeLast:(NSUInteger)count;

/// Combines the latest values from the receiver and the given signal into
/// RACTuples, once both have sent at least one `next`.
///
/// Any additional `next`s will result in a new RACTuple with the latest values
/// from both signals.
///
/// signal - The signal to combine with. This argument must not be nil.
///
/// Returns a signal which sends RACTuples of the combined values, forwards any
/// `error` events, and completes when both input signals complete.
- (RACSignal *)combineLatestWith:(RACSignal *)signal;

/// Combines the latest values from the given signals into RACTuples, once all
/// the signals have sent at least one `next`.
///
/// Any additional `next`s will result in a new RACTuple with the latest values
/// from all signals.
///
/// signals - The signals to combine. If this collection is empty, the returned
///           signal will immediately complete upon subscription.
///
/// Returns a signal which sends RACTuples of the combined values, forwards any
/// `error` events, and completes when all input signals complete.
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals;

/// Combines signals using +combineLatest:, then reduces the resulting tuples
/// into a single value using -reduceEach:.
///
/// signals     - The signals to combine. If this collection is empty, the
///               returned signal will immediately complete upon subscription.
/// reduceBlock - The block which reduces the latest values from all the
///               signals into one value. It must take as many arguments as the
///               number of signals given. Each argument will be an object
///               argument. The return value must be an object. This argument
///               must not be nil.
///
/// Example:
///
///   [RACSignal combineLatest:@[ stringSignal, intSignal ] reduce:^(NSString *string, NSNumber *number) {
///       return [NSString stringWithFormat:@"%@: %@", string, number];
///   }];
///
/// Returns a signal which sends the results from each invocation of
/// `reduceBlock`.
+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock;

/// Sends the latest `next` from any of the signals.
///
/// Returns a signal that passes through values from each of the given signals,
/// and sends `completed` when all of them complete. If any signal sends an error,
/// the returned signal sends `error` immediately.
+ (RACSignal *)merge:(id<NSFastEnumeration>)signals;

/// Merges the signals sent by the receiver into a flattened signal, but only
/// subscribes to `maxConcurrent` number of signals at a time.
///
/// When the receiver sends new signals while `maxConcurrent` signals are
/// already subscribed to, `policy` determines what the behavior should be.
///
/// This corresponds to `Merge<TSource>(IObservable<IObservable<TSource>>, Int32)`
/// in Rx.
///
/// maxConcurrent - The maximum number of signals to subscribe to at a
///                 time. This must be greater than 0.
/// policy        - Describes what to do when `maxConcurrent` is exceeded.
///
/// Returns a signal that forwards values from up to `maxConcurrent` signals at
/// a time. If an error occurs on any of the signals, it is sent on the returned
/// signal immediately. The returned signal will complete only after all input
/// signals have completed or been disposed.
- (RACSignal *)flatten:(NSUInteger)maxConcurrent withPolicy:(RACSignalFlattenPolicy)policy;

/// Concats the inner signals of a signal of signals.
- (RACSignal *)concat;

/// Aggregates the `next` values of the receiver into a single combined value.
///
/// The algorithm proceeds as follows:
///
///  1. `start` is passed into the block as the `running` value, and the first
///     element of the receiver is passed into the block as the `next` value.
///  2. The result of the invocation (`running`) and the next element of the
///     receiver (`next`) is passed into `block`.
///  3. Steps 2 and 3 are repeated until all values have been processed.
///  4. The last result of `block` is sent on the returned signal.
///
/// This method is similar to -scanWithStart:reduce:, except that only the
/// final result is sent on the returned signal.
///
/// startingValue - The value to be combined with the first element of the
///                 receiver. This value may be `nil`.
/// block         - A block that describes how to combine values of the
///                 receiver. If the receiver is empty, this block will never be
///                 invoked.
///
/// Returns a signal that will send the aggregated value when the receiver
/// completes, then itself complete. If the receiver never sends any values,
/// `startingValue` will be sent instead.
- (RACSignal *)aggregateWithStart:(id)startingValue reduce:(id (^)(id running, id next))block;

/// Invokes -setKeyPath:onObject:nilValue: with `nil` for the nil value.
- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object;

/// Binds the receiver to an object, automatically setting the given key path on
/// every `next`. When the signal completes, the binding is automatically
/// disposed of.
///
/// Sending an error on the signal is considered undefined behavior, and will
/// generate an assertion failure in Debug builds.
///
/// A given key on an object should only have one active signal bound to it at any
/// given time. Binding more than one signal to the same property is considered
/// undefined behavior.
///
/// keyPath  - The key path to update with `next`s from the receiver.
/// object   - The object that `keyPath` is relative to.
/// nilValue - The value to set at the key path whenever `nil` is sent by the
///            receiver. This may be nil when binding to object properties, but
///            an NSValue should be used for primitive properties, to avoid an
///            exception if `nil` is sent (which might occur if an intermediate
///            object is set to `nil`).
///
/// Returns a disposable which can be used to terminate the binding.
- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object nilValue:(id)nilValue;

/// Sends NSDate.date every `interval` seconds.
///
/// interval  - The time interval in seconds at which the current time is sent.
/// scheduler - The scheduler upon which the current NSDate should be sent. This
///             must not be nil or +[RACScheduler immediateScheduler].
///
/// Returns a signal that sends the current date/time every `interval` on
/// `scheduler`.
+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;

/// Sends NSDate.date at intervals of at least `interval` seconds, up to
/// approximately `interval` + `leeway` seconds.
///
/// The created signal will defer sending each `next` for at least `interval`
/// seconds, and for an additional amount of time up to `leeway` seconds in the
/// interest of performance or power consumption. Note that some additional
/// latency is to be expected, even when specifying a `leeway` of 0.
///
/// interval  - The base interval between `next`s.
/// scheduler - The scheduler upon which the current NSDate should be sent. This
///             must not be nil or +[RACScheduler immediateScheduler].
/// leeway    - The maximum amount of additional time the `next` can be deferred.
///
/// Returns a signal that sends the current date/time at intervals of at least
/// `interval seconds` up to approximately `interval` + `leeway` seconds on
/// `scheduler`.
+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway;

/// Take `next`s until the `signalTrigger` sends `next` or `completed`.
///
/// Returns a signal which passes through all events from the receiver until
/// `signalTrigger` sends `next` or `completed`, at which point the returned signal
/// will send `completed`.
- (RACSignal *)takeUntil:(RACSignal *)signalTrigger;

/// Take `next`s until the `replacement` sends an event.
///
/// replacement - The signal which replaces the receiver as soon as it sends an
///               event.
///
/// Returns a signal which passes through `next`s and `error` from the receiver
/// until `replacement` sends an event, at which point the returned signal will
/// send that event and switch to passing through events from `replacement`
/// instead, regardless of whether the receiver has sent events already.
- (RACSignal *)takeUntilReplacement:(RACSignal *)replacement;

/// Subscribe to the returned signal when an error occurs.
- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock;

/// Subscribe to the given signal when an error occurs.
- (RACSignal *)catchTo:(RACSignal *)signal;

/// Runs `tryBlock` against each of the receiver's values, passing values
/// until `tryBlock` returns NO, or the receiver completes.
///
/// tryBlock - An action to run against each of the receiver's values.
///            The block should return YES to indicate that the action was
///            successful. This block must not be nil.
///
/// Example:
///
///   // The returned signal will send an error if data values cannot be
///   // written to `someFileURL`.
///   [signal try:^(NSData *data, NSError **errorPtr) {
///       return [data writeToURL:someFileURL options:NSDataWritingAtomic error:errorPtr];
///   }];
///
/// Returns a signal which passes through all the values of the receiver. If
/// `tryBlock` fails for any value, the returned signal will error using the
/// `NSError` passed out from the block.
- (RACSignal *)try:(BOOL (^)(id value, NSError **errorPtr))tryBlock;

/// Runs `mapBlock` against each of the receiver's values, mapping values until
/// `mapBlock` returns nil, or the receiver completes.
///
/// mapBlock - An action to map each of the receiver's values. The block should
///            return a non-nil value to indicate that the action was successful.
///            This block must not be nil.
///
/// Example:
///
///   // The returned signal will send an error if data cannot be read from
///   // `fileURL`.
///   [signal tryMap:^(NSURL *fileURL, NSError **errorPtr) {
///       return [NSData dataWithContentsOfURL:fileURL options:0 error:errorPtr];
///   }];
///
/// Returns a signal which transforms all the values of the receiver. If
/// `mapBlock` returns nil for any value, the returned signal will error using
/// the `NSError` passed out from the block.
- (RACSignal *)tryMap:(id (^)(id value, NSError **errorPtr))mapBlock;

/// Returns the first `next`. Note that this is a blocking call.
- (id)first;

/// Returns the first `next` or `defaultValue` if the signal completes or errors
/// without sending a `next`. Note that this is a blocking call.
- (id)firstOrDefault:(id)defaultValue;

/// Returns the first `next` or `defaultValue` if the signal completes or errors
/// without sending a `next`. If an error occurs success will be NO and error
/// will be populated. Note that this is a blocking call.
///
/// Both success and error may be NULL.
- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error;

/// Blocks the caller and waits for the signal to complete.
///
/// error - If not NULL, set to any error that occurs.
///
/// Returns whether the signal completed successfully. If NO, `error` will be set
/// to the error that occurred.
- (BOOL)waitUntilCompleted:(NSError **)error;

/// Add every `next` to an array.
///
/// Note that this is a **blocking** call.
///
/// Returns the array of `next` values, or nil if an error occurs. Any `nil`
/// values sent from the signal will be represented as `NSNull`s in the array.
- (NSArray *)array;

/// Defer creation of a signal until the signal's actually subscribed to.
///
/// This can be used to effectively turn a hot signal into a cold signal, or to
/// perform side effects before subscription.
+ (RACSignal *)defer:(RACSignal * (^)(void))block;

/// Every time the receiver sends a new RACSignal, subscribes and sends `next`s and
/// `error`s only for that signal.
///
/// The receiver must be a signal of signals.
///
/// Returns a signal which passes through `next`s and `error`s from the latest
/// signal sent by the receiver, and sends `completed` when both the receiver and
/// the last sent signal complete.
- (RACSignal *)switchToLatest;

/// Switches between the signals in `cases` as well as `defaultSignal` based on
/// the latest value sent by `signal`.
///
/// signal        - A signal of objects used as keys in the `cases` dictionary.
///                 This argument must not be nil.
/// cases         - A dictionary that has signals as values. This argument must
///                 not be nil. A RACTupleNil key in this dictionary will match
///                 nil `next` events that are received on `signal`.
/// defaultSignal - The signal to pass through after `signal` sends a value for
///                 which `cases` does not contain a signal. If nil, any
///                 unmatched values will result in
///                 a RACSignalErrorNoMatchingCase error.
///
/// Returns a signal which passes through `next`s and `error`s from one of the
/// the signals in `cases` or `defaultSignal`, and sends `completed` when both
/// `signal` and the last used signal complete. If no `defaultSignal` is given,
/// an unmatched `next` will result in an error on the returned signal.
+ (RACSignal *)switch:(RACSignal *)signal cases:(NSDictionary *)cases default:(RACSignal *)defaultSignal;

/// Switches between `trueSignal` and `falseSignal` based on the latest value
/// sent by `boolSignal`.
///
/// boolSignal  - A signal of BOOLs determining whether `trueSignal` or
///               `falseSignal` should be active. This argument must not be nil.
/// trueSignal  - The signal to pass through after `boolSignal` has sent YES.
///               This argument must not be nil.
/// falseSignal - The signal to pass through after `boolSignal` has sent NO. This
///               argument must not be nil.
///
/// Returns a signal which passes through `next`s and `error`s from `trueSignal`
/// and/or `falseSignal`, and sends `completed` when both `boolSignal` and the
/// last switched signal complete.
+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal;

/// Deduplicates subscriptions to the receiver, and shares results between them,
/// ensuring that only one subscription is active at a time.
///
/// This is useful to ensure that a signal's side effects are never performed
/// multiple times _concurrently_. It _does not_ prevent a signal's side effects
/// from being repeated multiple times serially.
///
/// This operator corresponds to the `RefCount` method in Rx.
///
/// Returns a signal that will have at most one subscription to the receiver at
/// any time. When the returned signal gets its first subscriber, the underlying
/// signal is subscribed to. When the returned signal has no subscribers, the
/// underlying subscription is disposed. Whenever an underlying subscription is
/// already open, new subscribers to the returned signal will receive all events
/// sent so far.
- (RACSignal *)shareWhileActive;

/// Sends an error after `interval` seconds if the source doesn't complete
/// before then.
///
/// The error will be in the RACSignalErrorDomain and have a code of
/// RACSignalErrorTimedOut.
///
/// interval  - The number of seconds after which the signal should error out.
/// scheduler - The scheduler upon which any timeout error should be sent. This
///             must not be nil or +[RACScheduler immediateScheduler].
///
/// Returns a signal that passes through the receiver's events, until the
/// receiver finishes or times out, at which point an error will be sent on
/// `scheduler`.
- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler;

/// Creates and returns a signal that delivers its events on the given scheduler.
/// Any side effects of the receiver will still be performed on the original
/// thread.
///
/// This is ideal when the signal already performs its work on the desired
/// thread, but you want to handle its events elsewhere.
///
/// This corresponds to the `ObserveOn` method in Rx.
- (RACSignal *)deliverOn:(RACScheduler *)scheduler;

/// Creates and returns a signal that executes its side effects and delivers its
/// events on the given scheduler.
///
/// Use of this operator should be avoided whenever possible, because the
/// receiver's side effects may not be safe to run on another thread. If you just
/// want to receive the signal's events on `scheduler`, use -deliverOn: instead.
- (RACSignal *)subscribeOn:(RACScheduler *)scheduler;

/// Resubscribes to the receiving signal if an error occurs, up until it has
/// retried the given number of times.
///
/// retryCount - if 0, it keeps retrying until it completes.
- (RACSignal *)retry:(NSUInteger)retryCount;

/// Resubscribes to the receiving signal if an error occurs.
- (RACSignal *)retry;

/// Sends the latest value from the receiver only when `sampler` sends a value.
/// The returned signal could repeat values if `sampler` fires more often than
/// the receiver. Values from `sampler` are ignored before the receiver sends
/// its first value.
///
/// sampler - The signal that controls when the latest value from the receiver
///           is sent. Cannot be nil.
- (RACSignal *)sample:(RACSignal *)sampler;

/// Ignores all `next`s from the receiver.
///
/// Returns a signal which only passes through `error` or `completed` events from
/// the receiver.
- (RACSignal *)ignoreValues;

/// Converts each of the receiver's events into a RACEvent object.
///
/// Returns a signal which sends the receiver's events as RACEvents, and
/// completes after the receiver sends `completed` or `error`.
- (RACSignal *)materialize;

/// Converts each RACEvent in the receiver back into "real" RACSignal events.
///
/// Returns a signal which sends `next` for each value RACEvent, `error` for each
/// error RACEvent, and `completed` for each completed RACEvent.
- (RACSignal *)dematerialize;

/// Inverts each NSNumber-wrapped BOOL sent by the receiver. It will assert if
/// the receiver sends anything other than NSNumbers.
///
/// Returns a signal of inverted NSNumber-wrapped BOOLs.
- (RACSignal *)not;

/// Performs a boolean AND on all of the RACTuple of NSNumbers in sent by the receiver.
///
/// Asserts if the receiver sends anything other than a RACTuple of one or more NSNumbers.
///
/// Returns a signal that applies AND to each NSNumber in the tuple.
- (RACSignal *)and;

/// Performs a boolean OR on all of the RACTuple of NSNumbers in sent by the receiver.
///
/// Asserts if the receiver sends anything other than a RACTuple of one or more NSNumbers.
/// 
/// Returns a signal that applies OR to each NSNumber in the tuple.
- (RACSignal *)or;

/// Lazily binds a block to the values in the receiver.
///
/// This should only be used if you need to terminate the bind early, or close
/// over some state. -flattenMap: is more appropriate for all other cases.
///
/// block - A block returning a RACSignalBindBlock. This block will be invoked
///         each time the signal is subscribed to. This block must not be nil or
///         return nil.
///
/// Returns a new signal which represents the combination of all signals
/// returned from the lazy applications of `block`. The resulting signal will
/// forward events from all of the original signals in the order that they
/// arrive.
- (RACSignal *)bind:(RACSignalBindBlock (^)(void))block;

@end

@interface RACSignal (DeprecatedOperations)

@property (nonatomic, strong, readonly) RACSequence *sequence RACDeprecated("Transform the signal instead");

- (RACSignal *)throttle:(NSTimeInterval)interval RACDeprecated("Renamed to -throttleDiscardingEarliest:");
- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate RACDeprecated("Use a signal of signals and -flatten:withPolicy: with RACSignalFlattenPolicyDisposeEarliest instead");
- (RACSignal *)initially:(void (^)(void))block RACDeprecated("Put side effects into +defer: instead");
- (RACSignal *)finally:(void (^)(void))block RACDeprecated("Renamed to -doFinished:");
- (RACSignal *)flatten:(NSUInteger)maxConcurrent RACDeprecated("Use -flatten:withPolicy: with RACSignalFlattenPolicyQueue instead");
- (RACSignal *)takeUntilBlock:(BOOL (^)(id x))predicate RACDeprecated("Use -takeWhile: instead");
- (RACSignal *)takeWhileBlock:(BOOL (^)(id x))predicate RACDeprecated("Renamed to -takeWhile:");
- (RACSignal *)skipUntilBlock:(BOOL (^)(id x))predicate RACDeprecated("Use -skipWhile: instead");
- (RACSignal *)skipWhileBlock:(BOOL (^)(id x))predicate RACDeprecated("Renamed to -skipWhile:");
- (RACSignal *)any RACDeprecated("Use -take: with -mapReplace: and -concat: instead");
- (RACSignal *)any:(BOOL (^)(id object))predicateBlock RACDeprecated("Use -filter: and -take: instead");
- (RACSignal *)all:(BOOL (^)(id object))predicateBlock RACDeprecated("Use -flattenMap: and -take: instead");
- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock RACDeprecated("Use -map: instead");
- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock RACDeprecated("Use -map: instead");
- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock RACDeprecated("Use +defer: and -aggregateWithStart:reduce: instead");
- (RACSignal *)then:(RACSignal * (^)(void))block RACDeprecated("Use -ignoreValues followed by -concat: with +defer: instead");
- (RACMulticastConnection *)publish RACDeprecated("Send events to a shared RACSubject instead");
- (RACMulticastConnection *)multicast:(RACSubject *)subject RACDeprecated("Send events to a shared RACSubject instead");
- (RACSignal *)replay RACDeprecated("Bind to a property with RAC() instead");
- (RACSignal *)replayLast RACDeprecated("Bind to a property with RAC() instead");
- (RACSignal *)replayLazily RACDeprecated("Bind to a property with RAC() or use -shareWhileActive instead");
- (NSArray *)toArray RACDeprecated("Renamed to -array");

@end

@interface RACSignal (UnavailableOperations)

- (RACSignal *)windowWithStart:(RACSignal *)openSignal close:(RACSignal * (^)(RACSignal *start))closeBlock __attribute__((unavailable("See https://github.com/ReactiveCocoa/ReactiveCocoa/issues/587")));
- (RACSignal *)buffer:(NSUInteger)bufferCount __attribute__((unavailable("See https://github.com/ReactiveCocoa/ReactiveCocoa/issues/587")));
- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock __attribute__((unavailable("Send events to a shared RACSubject instead")));
+ (RACSignal *)interval:(NSTimeInterval)interval __attribute__((unavailable("Use +interval:onScheduler: instead")));
+ (RACSignal *)interval:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway __attribute__((unavailable("Use +interval:onScheduler:withLeeway: instead")));
- (RACSignal *)bufferWithTime:(NSTimeInterval)interval __attribute__((unavailable("Use -bufferWithTime:onScheduler: instead")));
- (RACSignal *)timeout:(NSTimeInterval)interval __attribute__((unavailable("Use -timeout:onScheduler: instead")));
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object __attribute__((unavailable("Renamed to -setKeyPath:onObject:")));
- (RACSignal *)ignoreElements __attribute__((unavailable("Renamed to -ignoreValues")));
- (RACSignal *)sequenceNext:(RACSignal * (^)(void))block __attribute__((unavailable("Renamed to -then:")));
- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock __attribute__((unavailable("Renamed to -aggregateWithStart:reduce:")));
- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock __attribute__((unavailable("Renamed to -aggregateWithStartFactory:reduce:")));
- (RACDisposable *)executeCommand:(RACCommand *)command __attribute__((unavailable("Use -flattenMap: or -subscribeNext: instead")));

@end
