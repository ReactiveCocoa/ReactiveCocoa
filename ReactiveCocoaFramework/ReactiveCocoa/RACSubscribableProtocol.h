//
//  RACSubscribableProtocol.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EXTConcreteProtocol.h"
#import "RACStream.h"

extern NSString * const RACSubscribableErrorDomain;

typedef enum {
	// The error code used with -timeout:.
	RACSubscribableErrorTimedOut = 1,
} _RACSubscribableError;

typedef NSInteger RACSubscribableError;

@class RACCancelableSubscribable;
@class RACConnectableSubscribable;
@class RACDisposable;
@class RACScheduler;
@class RACSequence;
@class RACSubject;
@class RACSubscribable;
@class RACTuple;
@protocol RACSubscriber;

// A concrete protocol representing something that can be subscribed to. Most
// commonly, this will simply be an instance of RACSubscribable (the class), but
// any class can conform to this protocol.
//
// When conforming to this protocol in a custom class, only `@required` methods
// need to be implemented. Default implementations will automatically be
// provided for any methods marked as `@concrete`. For more information, see
// EXTConcreteProtocol.h.
@protocol RACSubscribable <NSObject, RACStream>
@required

// Subscribes subscriber to changes on the receiver. The receiver defines which
// events it actually sends and in what situations the events are sent.
//
// Returns a disposable. You can call `-dispose` on it if you need to end your
// subscription before it would "naturally" end, either by completing or
// erroring. Once the disposable has been disposed, the subscriber won't receive
// any more events from the subscription.
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber;


// Combine values from each of the subscribables using `reduceBlock`.
// `reduceBlock` will be called with the first `next` of each subscribable, then
// with the second `next` of each subscribable, and so forth. If any of the
// subscribables sent `complete` or `error` after the nth `next`, then the
// resulting subscribable will also complete or error after the nth `next`.
//
// subscribables - The subscribables to combine.
// reduceBlock   - The block which reduces the latest values from all the
//                 subscribables into one value. It should take as many arguments
//                 as the number of subscribables given. Each argument will be an
//                 object argument, wrapped as needed. If nil, the returned
//                 subscribable will send a RACTuple of all the latest values.
+ (instancetype)zip:(NSArray *)streams reduce:(id)reduceBlock;

@concrete

// Convenience method to subscribe to the `next` event.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock;

// Convenience method to subscribe to the `next` and `completed` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to the `next`, `completed`, and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to `error` events.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `completed` events.
- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock;

// Convenience method to subscribe to `next` and `error` events.
- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `error` and `completed` events.
- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

// For each value sent on the receiving subscribable, the given object is sent
// on the returned subscribable.
//
// object - The object to send for each value sent on the receiver.
//
// Returns a subscribable that sends the given object for each value sent on the
// receiver.
- (id<RACSubscribable>)mapReplace:(id)object;

// Injects the given object weakly into the receiver's stream. The returned 
// subscribable sends a tuple where the first object is the value received by
// the receiver subscribable and the second is the weak object.
//
// This is most useful for bringing the caller's self into the subscribable 
// while preventing retain cycles so we don't always have to do the 
// weakObject / strongObject dance.
- (id<RACSubscribable>)injectObjectWeakly:(id)object;

// Do the given block on `next`. This should be used to inject side effects into
// a subscribable.
- (id<RACSubscribable>)doNext:(void (^)(id x))block;

// Do the given block on `error`. This should be used to inject side effects
// into a subscribable.
- (id<RACSubscribable>)doError:(void (^)(NSError *error))block;

// Do the given block on `completed`. This should be used to inject side effects
// into a subscribable.
- (id<RACSubscribable>)doCompleted:(void (^)(void))block;

// Only send `next` when we don't receive another `next` in `interval` seconds.
- (id<RACSubscribable>)throttle:(NSTimeInterval)interval;

// Sends `next` after delaying for `interval` seconds.
- (id<RACSubscribable>)delay:(NSTimeInterval)interval;

// Resubscribes when the subscribable completes.
- (id<RACSubscribable>)repeat;

// Execute the given block when the subscribable completes or errors.
- (id<RACSubscribable>)finally:(void (^)(void))block;

// Divide the `next`s of the subscribable into windows. When `openSubscribable`
// sends a next, a window is opened and the `closeBlock` is asked for a close
// subscribable. The window is closed when the close subscribable sends a `next`.
- (id<RACSubscribable>)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock;

// Divide the `next`s into buffers with `bufferCount` items each. The `next`
// will be a RACTuple of values.
- (id<RACSubscribable>)buffer:(NSUInteger)bufferCount;

// Divide the `next`s into buffers delivery every `interval` seconds. The `next`
// will be a RACTuple of values.
- (id<RACSubscribable>)bufferWithTime:(NSTimeInterval)interval;

// Takes the last `count` `next`s after the receiving subscribable completes.
- (id<RACSubscribable>)takeLast:(NSUInteger)count;

// Combine the latest values from each of the subscribables into a RACTuple, once
// all the subscribables have sent a `next`. Any additional `next`s will result
// in a new tuple with the changed value.
+ (id<RACSubscribable>)combineLatest:(NSArray *)subscribables;

// Combine the latest values from each of the subscribables once all the
// subscribables have sent a `next`. Any additional `next`s will result in a new
// reduced value based on all the latest values from all the subscribables.
//
// The `next` of the returned subscribable will be the return value of the
// `reduceBlock`.
//
// subscribables - The subscribables to combine.
// reduceBlock   - The block which reduces the latest values from all the
//                 subscribables into one value. It should take as many arguments
//                 as the number of subscribables given. Each argument will be an
//                 object argument, wrapped as needed. If nil, the returned
//                 subscribable will send a RACTuple of all the latest values.
//
// Example:
//   [RACSubscribable combineLatest:@[ stringSubscribable, intSubscribable ] reduce:^(NSString *string, NSNumber *wrappedInt) {
//       return [NSString stringWithFormat:@"%@: %@", string, wrappedInt];
//   }];
+ (id<RACSubscribable>)combineLatest:(NSArray *)subscribables reduce:(id)reduceBlock;

// Sends the latest `next` from any of the subscribables.
+ (id<RACSubscribable>)merge:(NSArray *)subscribables;

// Merges the subscribables sent by the receiver into a flattened subscribable,
// but only subscribes to `maxConcurrent` number of subscribables at a time. New
// subscribables are queued and subscribed to as other subscribables complete.
//
// If an error occurs on any of the subscribables, it is sent on the returned
// subscribable. It completes only after the receiver and all sent subscribables
// have completed.
//
// maxConcurrent - the maximum number of subscribables to subscribe to at a
//                 time. If 0, it subscribes to an unlimited number of
//                 subscribables.
- (id<RACSubscribable>)flatten:(NSUInteger)maxConcurrent;

// Gets a new subscribable to subscribe to after the receiver completes.
- (id<RACSubscribable>)sequenceNext:(id<RACSubscribable> (^)(void))block;

// Concats the inner subscribables of a subscribable of subscribables.
- (id<RACSubscribable>)concat;

// Aggregate `next`s with the given start and combination.
- (id<RACSubscribable>)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Aggregate `next`s with the given start and combination. The start factory 
// block is called to get a new start object for each subscription.
- (id<RACSubscribable>)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock;

// Similar to -aggregateWithStart:combine: with an important difference: it
// sends the combined value with each `next` instead of waiting for the
// receiving subscribable to complete.
- (id<RACSubscribable>)scanWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Set the object's keyPath to the value of `next`.
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object;

// Sends NSDate.date every `interval` seconds.
//
// interval - The time interval in seconds at which the current time is sent.
//
// Returns a subscribable that sends the current date/time every `interval`.
+ (id<RACSubscribable>)interval:(NSTimeInterval)interval;

// Take `next`s until the `subscribableTrigger` sends a `next`.
- (id<RACSubscribable>)takeUntil:(id<RACSubscribable>)subscribableTrigger;

// Take `next`s until the given block returns YES.
- (id<RACSubscribable>)takeUntilBlock:(BOOL (^)(id x))predicate;

// Take `next`s until the given block returns NO.
- (id<RACSubscribable>)takeWhileBlock:(BOOL (^)(id x))predicate;

// Convert every `next` and `error` into a RACMaybe.
- (id<RACSubscribable>)asMaybes;

// Subscribe to the returned subscribable when an error occurs.
- (id<RACSubscribable>)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock;

// Subscribe to the given subscribable when an error occurs.
- (id<RACSubscribable>)catchTo:(id<RACSubscribable>)subscribable;

// Returns the first `next`. Note that this is a blocking call.
- (id)first;

// Returns the first `next` or `defaultValue` if the subscribable completes or
// errors without sending a `next`. Note that this is a blocking call.
- (id)firstOrDefault:(id)defaultValue;

// Returns the first `next` or `defaultValue` if the subscribable completes or
// errors without sending a `next`. If an error occurs success will be NO
// and error will be populated. Note that this is a blocking call.
//
// Both success and error may be NULL.
- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error;

// Skips values until the block returns YES.
- (id<RACSubscribable>)skipUntilBlock:(BOOL (^)(id x))block;

// Skips values until the block returns NO.
- (id<RACSubscribable>)skipWhileBlock:(BOOL (^)(id x))block;

// Defer creation of a subscribable until the subscribable's actually subscribed to.
//
// This can be used to effectively turn a hot subscribable into a cold subscribable.
+ (id<RACSubscribable>)defer:(id<RACSubscribable> (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the
// previous `next`.
- (id<RACSubscribable>)distinctUntilChanged;

// The source must be a subscribable of subscribables. Subscribe and send
// `next`s for the latest subscribable. This is mostly useful when combined
// with `-flattenMap:`.
- (id<RACSubscribable>)switch;

// Add every `next` to an array. Nils are represented by NSNulls. Note that this
// is a blocking call.
- (NSArray *)toArray;

// Add every `next` to a sequence. Nils are represented by NSNulls.
//
// Returns a sequence which provides values from the subscribable as they're
// sent. Trying to retrieve a value from the sequence which has not yet been
// sent will block.
@property (nonatomic, strong, readonly) RACSequence *sequence;

// Creates and returns a connectable subscribable. This allows you to share a
// single subscription to the underlying subscribable.
- (RACConnectableSubscribable *)publish;

// Creates and returns a connectable subscribable that pushes values into the
// given subject. This allows you to share a single subscription to the
// underlying subscribable.
- (RACConnectableSubscribable *)multicast:(RACSubject *)subject;

// Sends an error after `interval` seconds if the source doesn't complete
// before then. The timeout is scheduled on the default priority global queue.
- (id<RACSubscribable>)timeout:(NSTimeInterval)interval;

// Creates and returns a subscribable that delivers its callbacks using the
// given scheduler.
- (id<RACSubscribable>)deliverOn:(RACScheduler *)scheduler;

// Creates and returns a subscribable whose `didSubscribe` block is scheduled
// with the given scheduler.
- (id<RACSubscribable>)subscribeOn:(RACScheduler *)scheduler;

// Creates a shared subscribable which is passed into the let block. The let
// block then returns a subscribable derived from that shared subscribable.
- (id<RACSubscribable>)let:(id<RACSubscribable> (^)(id<RACSubscribable> sharedSubscribable))letBlock;

// Groups each received object into a group, as determined by calling `keyBlock`
// with that object. The object sent is transformed by calling `transformBlock`
// with the object. If `transformBlock` is nil, it sends the original object.
//
// The returned subscribable is a subscribable of RACGroupedSubscribables.
- (id<RACSubscribable>)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock;

// Calls -[RACSubscribable groupBy:keyBlock transform:nil].
- (id<RACSubscribable>)groupBy:(id<NSCopying> (^)(id object))keyBlock;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects.
- (id<RACSubscribable>)any;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects that pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (id<RACSubscribable>)any:(BOOL (^)(id object))predicateBlock;

// Sends an [NSNumber numberWithBool:YES] if all the objects the receiving 
// subscribable sends pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (id<RACSubscribable>)all:(BOOL (^)(id object))predicateBlock;

// Resubscribes to the receiving subscribable if an error occurs, up until it 
// has retried the given number of times.
//
// retryCount - if 0, it keeps retrying until it completes.
- (id<RACSubscribable>)retry:(NSInteger)retryCount;

// Resubscribes to the receiving subscribable if an error occurs.
- (id<RACSubscribable>)retry;

// Creates a cancelable subscribable multicasted to the given subject with the
// given cancelation block.
- (RACCancelableSubscribable *)asCancelableToSubject:(RACSubject *)subject withBlock:(void (^)(void))block;

// Creates a cancelable subscribable with the given cancelation block.
- (RACCancelableSubscribable *)asCancelableWithBlock:(void (^)(void))block;

// Creates a cancelable subscribable.
- (RACCancelableSubscribable *)asCancelable;

@end
