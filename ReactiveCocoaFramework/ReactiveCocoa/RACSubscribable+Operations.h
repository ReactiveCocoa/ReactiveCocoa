//
//  RACSubscribable+Operations.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable.h"


@interface RACSubscribable (Operations)

// Transform each `next` value by calling the given block.
- (instancetype)select:(id (^)(id x))selectBlock;

// Only send `next` when the given block returns YES.
- (instancetype)where:(BOOL (^)(id x))whereBlock;

// Do the given block on `next`. This can be used to inject side effects into a subscribable.
- (instancetype)doNext:(void (^)(id x))block;

// Only send `next` when we don't receive another `next` in `interval` seconds.
- (instancetype)throttle:(NSTimeInterval)interval;

// Sends `next` after delaying for `interval` seconds.
- (instancetype)delay:(NSTimeInterval)interval;

// Resubscribes when the subscribable completes.
- (instancetype)repeat;

// Execute the given block when the subscribable completes or errors.
- (instancetype)finally:(void (^)(void))block;

// Divide the `next`s of the subscribable into windows. When `openSubscribable` sends a next, a window is opened and the `closeBlock` is asked for a close subscribable. The window is closed when the close subscribable sends a `next`.
- (instancetype)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock;

// Divide the `next`s into buffers with `bufferCount` items each.
- (instancetype)buffer:(NSUInteger)bufferCount;

// Take `count` `next`s and then completes.
- (instancetype)take:(NSUInteger)count;

// Combine the latest values from each of the subscribables once all the subscribables have sent a `next`.
+ (instancetype)combineLatest:(NSArray *)observables reduce:(id (^)(NSArray *xs))reduceBlock;

// Sends a `+[RACUnit defaultUnit]` when all the subscribables have sent a `next`.
+ (instancetype)whenAll:(NSArray *)observables;

// Sends the latest `next` from any of the subscribables.
+ (instancetype)merge:(NSArray *)observables;

// Gets a new subscribable for every `next` and sends `next` when any of those subscribables do.
- (instancetype)selectMany:(id<RACSubscribable> (^)(id x))selectBlock;

// Subscribes to `subscribable` when the source subscribable completes.
- (instancetype)concat:(id<RACSubscribable>)subscribable;

// Combine `next`s with the given start and combination.
- (instancetype)scanWithStart:(NSInteger)start combine:(NSInteger (^)(NSInteger running, NSInteger next))combineBlock;

// Aggregate `next`s with the given start and combination.
- (instancetype)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;

// Set the object's keyPath to the value of `next`.
- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object;

// Send `next` with `initialValue` before getting the first `next`.
- (instancetype)startWith:(id)initialValue;

// Sends `+[RACUnit defaultUnit]` every `interval` seconds.
+ (instancetype)interval:(NSTimeInterval)interval;

// Take `next`s until the `subscribableTrigger` sends a `next`.
- (instancetype)takeUntil:(id<RACSubscribable>)subscribableTrigger;

// Take `next`s until the given block returns NO.
- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate;

// Convert every `next` and `error` into a RACMaybe.
- (instancetype)catchToMaybe;

// Subscribe to the returned subscribable when an error occurs.
- (instancetype)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock;

// Subscribe to the given subscribable when an error occurs.
- (instancetype)catchTo:(id<RACSubscribable>)subscribable;

// Returns the first `next`. Note that this is a blocking call.
- (id)first;

// Returns the first `next` or `defaultValue` if the subscribable completes or errors without sending a `next`. Note that this is a blocking call.
- (id)firstOrDefault:(id)defaultValue;

// Skip the first `skipCount` `next`s.
- (instancetype)skip:(NSUInteger)skipCount;

// Defer creation of a subscribable until the subscribable's actually subscribed to.
+ (instancetype)defer:(id<RACSubscribable> (^)(void))block;

// Send only `next`s for which -isEqual: returns NO when compared to the previous `next`.
- (instancetype)distinctUntilChanged;

// The source must be a subscribable of subscribables. Subscribe and send `next`s for the latest subscribable. This is mostly useful when combined with `-selectMany:`.
- (instancetype)switch;

// Add every `next` to an array. Note that this is a blocking call.
- (NSArray *)toArray;

@end
