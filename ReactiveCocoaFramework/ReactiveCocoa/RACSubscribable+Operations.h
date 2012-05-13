//
//  RACSubscribable+Operations.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"

extern NSString * const RACSubscribableErrorDomain;

typedef enum {
	// The error code used with -timeout:.
	RACSubscribableErrorTimedOut = 1,
} _RACSubscribableError;

typedef NSInteger RACSubscribableError;

@class RACTuple;
@class RACConnectableSubscribable;
@class RACSubject;
@class RACScheduler;


@interface RACSubscribable (Operations)

// Transform each `next` value by calling the given block.
- (RACSubscribable *)select:(id (^)(id x))selectBlock;

// Injects the given object weakly into the receiver's stream. The returned 
// subscribable sends a tuple where the first object is the value received by
// the receiver subscribable and the second is the weak object.
//
// This is most useful for bringing the caller's self into the subscribable 
// while preventing retain cycles so we don't always have to do the 
// weakObject / strongObject dance.
- (RACSubscribable *)injectObjectWeakly:(id)object;

// Only send `next` when the given block returns YES.
- (RACSubscribable *)where:(BOOL (^)(id x))whereBlock;

// Do the given block on `next`. This can be used to inject side effects into a
// subscribable.
- (RACSubscribable *)doNext:(void (^)(id x))block;

// Only send `next` when we don't receive another `next` in `interval` seconds.
- (RACSubscribable *)throttle:(NSTimeInterval)interval;

// Sends `next` after delaying for `interval` seconds.
- (RACSubscribable *)delay:(NSTimeInterval)interval;

// Resubscribes when the subscribable completes.
- (RACSubscribable *)repeat;

// Execute the given block when the subscribable completes or errors.
- (RACSubscribable *)finally:(void (^)(void))block;

// Divide the `next`s of the subscribable into windows. When `openSubscribable`
// sends a next, a window is opened and the `closeBlock` is asked for a close
// subscribable. The window is closed when the close subscribable sends a `next`.
- (RACSubscribable *)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock;

// Divide the `next`s into buffers with `bufferCount` items each. The `next`
// will be a RACTuple of values.
- (RACSubscribable *)buffer:(NSUInteger)bufferCount;

// Divide the `next`s into buffers delivery every `interval` seconds. The `next`
// will be a RACTuple of values.
- (RACSubscribable *)bufferWithTime:(NSTimeInterval)interval;

// Take `count` `next`s and then completes.
- (RACSubscribable *)take:(NSUInteger)count;

// Combine the latest values from each of the subscribables once all the
// subscribables have sent a `next`.
+ (RACSubscribable *)combineLatest:(NSArray *)subscribables reduce:(id (^)(RACTuple *xs))reduceBlock;

// Sends a `+[RACUnit defaultUnit]` when all the subscribables have sent a `next`.
+ (RACSubscribable *)whenAll:(NSArray *)subscribables;

// Sends the latest `next` from any of the subscribables.
+ (RACSubscribable *)merge:(NSArray *)subscribables;

// Merge the subscribable with the given subscribable.
- (RACSubscribable *)merge:(RACSubscribable *)subscribable;

// Merges the subscribable of subscribables into a flattened subscribable.
- (RACSubscribable *)merge;

// Gets a new subscribable for every `next` and sends `next` when any of those
// subscribables do.
- (RACSubscribable *)selectMany:(id<RACSubscribable> (^)(id x))selectBlock;

// Subscribes to `subscribable` when the source subscribable completes.
- (RACSubscribable *)concat:(id<RACSubscribable>)subscribable;

// Combine `next`s with the given start and combination.
- (RACSubscribable *)scanWithStart:(NSInteger)start combine:(NSInteger (^)(NSInteger running, NSInteger next))combineBlock;

// Aggregate `next`s with the given start and combination.
- (RACSubscribable *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Set the object's keyPath to the value of `next`.
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object;

// Send `next` with `initialValue` before getting the first `next`.
- (RACSubscribable *)startWith:(id)initialValue;

// Sends `+[RACUnit defaultUnit]` every `interval` seconds.
+ (RACSubscribable *)interval:(NSTimeInterval)interval;

// Take `next`s until the `subscribableTrigger` sends a `next`.
- (RACSubscribable *)takeUntil:(id<RACSubscribable>)subscribableTrigger;

// Take `next`s until the given block returns NO.
- (RACSubscribable *)takeUntilBlock:(BOOL (^)(id x))predicate;

// Convert every `next` and `error` into a RACMaybe.
- (RACSubscribable *)asMaybes;

// Subscribe to the returned subscribable when an error occurs.
- (RACSubscribable *)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock;

// Subscribe to the given subscribable when an error occurs.
- (RACSubscribable *)catchTo:(id<RACSubscribable>)subscribable;

// Returns the first `next`. Note that this is a blocking call.
- (id)first;

// Returns the first `next` or `defaultValue` if the subscribable completes or
// errors without sending a `next`. Note that this is a blocking call.
- (id)firstOrDefault:(id)defaultValue;

// Skip the first `skipCount` `next`s.
- (RACSubscribable *)skip:(NSUInteger)skipCount;

// Defer creation of a subscribable until the subscribable's actually subscribed to.
//
// This can be used to effectively turn a hot subscribable into a cold subscribable.
+ (RACSubscribable *)defer:(id<RACSubscribable> (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the
// previous `next`.
- (RACSubscribable *)distinctUntilChanged;

// The source must be a subscribable of subscribables. Subscribe and send
// `next`s for the latest subscribable. This is mostly useful when combined
// with `-selectMany:`.
- (RACSubscribable *)switch;

// Add every `next` to an array. Nils are represented by NSNulls. Note that this
// is a blocking call.
- (NSArray *)toArray;

// Creates and returns a connectable subscribable. This allows you to share a
// single subscription to the underlying subscribable.
- (RACConnectableSubscribable *)publish;

// Creates and returns a connectable subscribable that pushes values into the
// given subject. This allows you to share a single subscription to the
// underlying subscribable.
- (RACConnectableSubscribable *)multicast:(RACSubject *)subject;

// Sends an error after `interval` seconds if the source doesn't complete
// before then.
- (RACSubscribable *)timeout:(NSTimeInterval)interval;

// Creates and returns a subscribable that delivers its callbacks using the
// given scheduler.
- (RACSubscribable *)deliverOn:(RACScheduler *)scheduler;

// Creates and returns a subscribable whose `didSubscribe` block is scheduled
// with the given scheduler.
- (RACSubscribable *)subscribeOn:(RACScheduler *)scheduler;

// Creates a shared subscribable which is passed into the let block. The let
// block then returns a subscribable derived from that shared subscribable.
- (RACSubscribable *)let:(RACSubscribable * (^)(RACSubscribable *sharedSubscribable))letBlock;

// Groups each received object into a group, as determined by calling `keyBlock`
// with that object. The object sent is transformed by calling `transformBlock`
// with the object. If `transformBlock` is nil, it sends the original object.
//
// The returned subscribable is a subscribable of RACGroupedSubscribables.
- (RACSubscribable *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock;

// Calls -[RACSubscribable groupBy:keyBlock transform:nil].
- (RACSubscribable *)groupBy:(id<NSCopying> (^)(id object))keyBlock;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects.
- (RACSubscribable *)any;

// Sends an [NSNumber numberWithBool:YES] if the receiving subscribable sends 
// any objects that pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (RACSubscribable *)any:(BOOL (^)(id object))predicateBlock;

// Sends an [NSNumber numberWithBool:YES] if all the objects the receiving 
// subscribable sends pass `predicateBlock`.
//
// predicateBlock - cannot be nil.
- (RACSubscribable *)all:(BOOL (^)(id object))predicateBlock;

// Resubscribes to the receiving subscribable if an error occurs, up until it 
// has retried the given number of times.
//
// retryCount - if 0, it keeps retrying until it completes.
- (RACSubscribable *)retry:(NSInteger)retryCount;

// Resubscribes to the receiving subscribable if an error occurs.
- (RACSubscribable *)retry;

@end
