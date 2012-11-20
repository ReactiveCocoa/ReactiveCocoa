//
//  RACSignalProtocol.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EXTConcreteProtocol.h"
#import "RACStream.h"

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
@class RACSignal;
@class RACTuple;
@protocol RACSubscriber;

// A concrete protocol representing something that can be subscribed to. Most
// commonly, this will simply be an instance of RACSignal (the class), but any
// class can conform to this protocol.
//
// When conforming to this protocol in a custom class, only `@required` methods
// need to be implemented. Default implementations will automatically be
// provided for any methods marked as `@concrete`. For more information, see
// EXTConcreteProtocol.h.
@protocol RACSignal <NSObject, RACStream>
@required

// Subscribes subscriber to changes on the receiver. The receiver defines which
// events it actually sends and in what situations the events are sent.
//
// Returns a disposable. You can call `-dispose` on it if you need to end your
// subscription before it would "naturally" end, either by completing or
// erroring. Once the disposable has been disposed, the subscriber won't receive
// any more events from the subscription.
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber;

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
- (id<RACSignal>)mapReplace:(id)object;

// Injects the given object weakly into the receiver's stream. The returned 
// subscribable sends a tuple where the first object is the value received by
// the receiver subscribable and the second is the weak object.
//
// This is most useful for bringing the caller's self into the subscribable 
// while preventing retain cycles so we don't always have to do the 
// weakObject / strongObject dance.
- (id<RACSignal>)injectObjectWeakly:(id)object;

// Do the given block on `next`. This should be used to inject side effects into
// a subscribable.
- (id<RACSignal>)doNext:(void (^)(id x))block;

// Do the given block on `error`. This should be used to inject side effects
// into a subscribable.
- (id<RACSignal>)doError:(void (^)(NSError *error))block;

// Do the given block on `completed`. This should be used to inject side effects
// into a subscribable.
- (id<RACSignal>)doCompleted:(void (^)(void))block;

// Only send `next` when we don't receive another `next` in `interval` seconds.
- (id<RACSignal>)throttle:(NSTimeInterval)interval;

// Sends `next` after delaying for `interval` seconds.
- (id<RACSignal>)delay:(NSTimeInterval)interval;

// Resubscribes when the subscribable completes.
- (id<RACSignal>)repeat;

// Execute the given block when the subscribable completes or errors.
- (id<RACSignal>)finally:(void (^)(void))block;

// Divide the `next`s of the subscribable into windows. When `openSubscribable`
// sends a next, a window is opened and the `closeBlock` is asked for a close
// subscribable. The window is closed when the close subscribable sends a `next`.
- (id<RACSignal>)windowWithStart:(id<RACSignal>)openSubscribable close:(id<RACSignal> (^)(id<RACSignal> start))closeBlock;

// Divide the `next`s into buffers with `bufferCount` items each. The `next`
// will be a RACTuple of values.
- (id<RACSignal>)buffer:(NSUInteger)bufferCount;

// Divide the `next`s into buffers delivery every `interval` seconds. The `next`
// will be a RACTuple of values.
- (id<RACSignal>)bufferWithTime:(NSTimeInterval)interval;

// Takes the last `count` `next`s after the receiving subscribable completes.
- (id<RACSignal>)takeLast:(NSUInteger)count;

// Combine the latest values from each of the subscribables into a RACTuple, once
// all the subscribables have sent a `next`. Any additional `next`s will result
// in a new tuple with the changed value.
+ (id<RACSignal>)combineLatest:(NSArray *)subscribables;

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
//   [RACSignal combineLatest:@[ stringSubscribable, intSubscribable ] reduce:^(NSString *string, NSNumber *wrappedInt) {
//       return [NSString stringWithFormat:@"%@: %@", string, wrappedInt];
//   }];
+ (id<RACSignal>)combineLatest:(NSArray *)subscribables reduce:(id)reduceBlock;

// Sends the latest `next` from any of the subscribables.
+ (id<RACSignal>)merge:(NSArray *)subscribables;

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
- (id<RACSignal>)flatten:(NSUInteger)maxConcurrent;

// Gets a new subscribable to subscribe to after the receiver completes.
- (id<RACSignal>)sequenceNext:(id<RACSignal> (^)(void))block;

// Concats the inner subscribables of a subscribable of subscribables.
- (id<RACSignal>)concat;

// Aggregate `next`s with the given start and combination.
- (id<RACSignal>)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Aggregate `next`s with the given start and combination. The start factory 
// block is called to get a new start object for each subscription.
- (id<RACSignal>)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock;

// Similar to -aggregateWithStart:combine: with an important difference: it
// sends the combined value with each `next` instead of waiting for the
// receiving subscribable to complete.
- (id<RACSignal>)scanWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Set the object's keyPath to the value of `next`.
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object;

// Sends NSDate.date every `interval` seconds.
//
// interval - The time interval in seconds at which the current time is sent.
//
// Returns a subscribable that sends the current date/time every `interval`.
+ (id<RACSignal>)interval:(NSTimeInterval)interval;

// Take `next`s until the `subscribableTrigger` sends a `next`.
- (id<RACSignal>)takeUntil:(id<RACSignal>)subscribableTrigger;

// Take `next`s until the given block returns YES.
- (id<RACSignal>)takeUntilBlock:(BOOL (^)(id x))predicate;

// Take `next`s until the given block returns NO.
- (id<RACSignal>)takeWhileBlock:(BOOL (^)(id x))predicate;

// Convert every `next` and `error` into a RACMaybe.
- (id<RACSignal>)asMaybes;

// Subscribe to the returned subscribable when an error occurs.
- (id<RACSignal>)catch:(id<RACSignal> (^)(NSError *error))catchBlock;

// Subscribe to the given subscribable when an error occurs.
- (id<RACSignal>)catchTo:(id<RACSignal>)subscribable;

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
- (id<RACSignal>)skipUntilBlock:(BOOL (^)(id x))block;

// Skips values until the block returns NO.
- (id<RACSignal>)skipWhileBlock:(BOOL (^)(id x))block;

// Defer creation of a subscribable until the subscribable's actually subscribed to.
//
// This can be used to effectively turn a hot subscribable into a cold subscribable.
+ (id<RACSignal>)defer:(id<RACSignal> (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the
// previous `next`.
- (id<RACSignal>)distinctUntilChanged;

// The source must be a subscribable of subscribables. Subscribe and send
// `next`s for the latest subscribable. This is mostly useful when combined
// with `-flattenMap:`.
- (id<RACSignal>)switch;

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
- (RACConnectableSignal *)publish;

// Creates and returns a connectable subscribable that pushes values into the
// given subject. This allows you to share a single subscription to the
// underlying subscribable.
- (RACConnectableSignal *)multicast:(RACSubject *)subject;

// Sends an error after `interval` seconds if the source doesn't complete
// before then. The timeout is scheduled on the default priority global queue.
- (id<RACSignal>)timeout:(NSTimeInterval)interval;

// Creates and returns a subscribable that delivers its callbacks using the
// given scheduler.
- (id<RACSignal>)deliverOn:(RACScheduler *)scheduler;

// Creates and returns a subscribable whose `didSubscribe` block is scheduled
// with the given scheduler.
- (id<RACSignal>)subscribeOn:(RACScheduler *)scheduler;

// Creates a shared subscribable which is passed into the let block. The let
// block then returns a subscribable derived from that shared subscribable.
- (id<RACSignal>)let:(id<RACSignal> (^)(id<RACSignal> sharedSubscribable))letBlock;

// Groups each received object into a group, as determined by calling `keyBlock`
// with that object. The object sent is transformed by calling `transformBlock`
// with the object. If `transformBlock` is nil, it sends the original object.
//
// The returned subscribable is a subscribable of RACGroupedSubscribables.
- (id<RACSignal>)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock;

// Calls -[RACSignal groupBy:keyBlock transform:nil].
- (id<RACSignal>)groupBy:(id<NSCopying> (^)(id object))keyBlock;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects.
- (id<RACSignal>)any;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects that pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (id<RACSignal>)any:(BOOL (^)(id object))predicateBlock;

// Sends an [NSNumber numberWithBool:YES] if all the objects the receiving 
// subscribable sends pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (id<RACSignal>)all:(BOOL (^)(id object))predicateBlock;

// Resubscribes to the receiving subscribable if an error occurs, up until it 
// has retried the given number of times.
//
// retryCount - if 0, it keeps retrying until it completes.
- (id<RACSignal>)retry:(NSInteger)retryCount;

// Resubscribes to the receiving subscribable if an error occurs.
- (id<RACSignal>)retry;

// Creates a cancelable subscribable multicasted to the given subject with the
// given cancelation block.
- (RACCancelableSignal *)asCancelableToSubject:(RACSubject *)subject withBlock:(void (^)(void))block;

// Creates a cancelable subscribable with the given cancelation block.
- (RACCancelableSignal *)asCancelableWithBlock:(void (^)(void))block;

// Creates a cancelable subscribable.
- (RACCancelableSignal *)asCancelable;

@end
