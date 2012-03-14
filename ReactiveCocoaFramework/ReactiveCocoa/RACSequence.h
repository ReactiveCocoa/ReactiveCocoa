//
//  RACSequence.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACObservable.h"
#import "RACQueryable.h"

@class RACCommand;

#define rac_synthesize_seq(a) \
	@synthesize a; \
	- (RACSequence *)a { \
		if(a == nil) { \
			a = [RACSequence sequence]; \
		} \
		return a; \
	}


// A sequence is essentially a stream of values. It can be observed and queried.
@interface RACSequence : NSObject <RACObservable>

// Creates a new sequence with the default capacity.
+ (id)sequence;

// Creates a new sequence with the given capacity. The capacity dictates how many values are held at once. When the capacity is exceeded, the sequence removes the oldest value.
+ (id)sequenceWithCapacity:(NSUInteger)capacity;

+ (RACSequence *)returnValue:(id)value;

// Adds a new object into the sequence. This will notify observers of this object.
//
// object - the object to insert into the sequence. Cannot be nil.
- (void)addObject:(id)object;

// Returns the last object added to the sequence. May be nil.
- (id)lastObject;

// Convenience method to subscribe to the `next` event.
- (RACObserver *)subscribeNext:(void (^)(id x))nextBlock;

// Convenience method to subscribe to the `next` and `completed` events.
- (RACObserver *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to the `next`, `completed`, and `error` events.
- (RACObserver *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to `error` events.
- (RACObserver *)subscribeError:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `completed` events.
- (RACObserver *)subscribeCompleted:(void (^)(void))completedBlock;

// Convenience method to subscribe to `next` and `error` events.
- (RACObserver *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock;

// Perform the given block on the `next` event. The observer is unregistered on `error` or `completed`.
//
// Returns self.
- (RACSequence *)doNext:(void (^)(id x))nextBlock;

// Perform the given block on the `error` event. The observer is unregistered on `completed`.
//
// Returns self.
- (RACSequence *)doError:(void (^)(NSError *error))errorBlock;

// Perform the given block on the `completed` event. The observer is unregistered on `error`.
//
// Returns self.
- (RACSequence *)doCompleted:(void (^)(void))completedBlock;

@end

@interface RACSequence (QueryableImplementations) <RACQueryable>

// Returns a sequence that adds only the objects from the receiver to which `predicate` returns YES.
// `next` is sent when the receiver sends a `next` and the `predicate` block returns YES. The `next` value is the value that the receiver got from `next`.
// `error` is sent when the receiver gets `error`.
// `completed` is sent when the receiver gets `completed`.
- (RACSequence *)where:(BOOL (^)(id x))predicate;

// Returns a sequence that adds the objects returned by calling `block` for each object added to the receiver.
// `next` is sent when the receiver sends a `next`. The `next` value is the value returned by calling `block` with the value of the receiver's `next`.
// `error` is sent when the receiver gets `error`.
// `completed` is sent when the receiver gets `completed`.
- (RACSequence *)select:(id (^)(id x))block;

// Returns a sequence that fires its `next` event only after the receiver hasn't received any new objects for `interval` seconds.
// `next` is sent only after `interval` has passed since the receiver's last `next`. The `next` value is the receiver's `-lastObject`.
// `error` is sent when the receiver gets `error`.
// `completed` is sent when the receiver gets `completed`.
- (RACSequence *)throttle:(NSTimeInterval)interval;

// Combine the latest values from the sequences and add the reduced value to the returned sequence.
// `next` is sent when a `next` is sent on any of the sequences and all sequences return non-nil for `-lastObject`. The `next` value is the value returned from calling `reduceBlock` with an array of the `-lastObject` for each of the sequences.
// `error` is sent when one of the sequences sends `error`.
// `completed` is sent once all the sequences have sent `completed`.
+ (RACSequence *)combineLatest:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock;

// Returns a sequence that adds the latest object any time any of the given sequences are added to.
// `next` is sent when any of the given sequences get `next`. The `next` value is value of whichever receiver got `next`.
// `error` is sent when as one of the sequences sends `error`.
// `completed` is sent once all the sequences have sent `completed`.
+ (RACSequence *)merge:(NSArray *)sequences;

// Returns an sequence that adds an NSArray of the last objects of each of the sequence each time an object is added to any of the sequences, *and* there is a last object for each of the sequences. This is different from `-combineLatest:reduce:` in that it waits for pairs of `next`'s to come in before sending `next`.
// `next` is sent after each of the given sequences has sent a `next` with a non-nil object. Its `next` value is the value returned from calling `reduceBlock` with an array of each of the values from the sequence's `next`'s.
// `error` is sent when one of the sequences sends `error`.
// `completed` is sent once all the sequences have sent `completed`.
+ (RACSequence *)zip:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock;

// Adds the last added object to the given sequence and returns self.
- (RACSequence *)toSequence:(RACSequence *)property;

// Sets the last added object to the value of the given key path and returns self.
- (RACSequence *)toObject:(NSObject *)object keyPath:(NSString *)keyPath;

// Returns a sequence that adds objects from the receiver only if they're not equal to the last added object added to the sequence.
// `next` is sent when the receiver gets a `next` with a value that is not equal to its `-lastObject`.
// `error` is sent when the receiver gets `error`.
// `completed` is sent when the receiver gets `completed`.
- (RACSequence *)distinctUntilChanged;

// Returns the sequence returned by the block. This can be used to chain different sequences together.
- (RACSequence *)selectMany:(RACSequence * (^)(id x))selectMany;

// Returns a sequence that only sends its `next` after the receiver has received `count` objects.
- (RACSequence *)take:(NSUInteger)count;

// Returns a sequence that adds objects from the receiver only until `untilSequence` gets a `next` or `error`.
// `next` is sent when the receiver gets a `next`. The `next` value is value of the receiver's `next`.
// `error` is sent when the receiver or `untilSequence` get `error`.
// `completed` is sent when the receiver gets `completed` or when `untilSequence` gets next.
- (RACSequence *)until:(RACSequence *)untilSequence;

// Returns a sequence that adds objects from the receiver only after `untilSequence` gets a `next`.
// `next` is sent when the receiver gets a `next` after `untilSequence` has received a `next`. The `next` value is the value of the receiver's `next`.
// `error` is sent when the receiver or `untilSequence` get `error`.
// `completed` is sent when the receiver gets `completed`.
- (RACSequence *)waitUntil:(RACSequence *)untilSequence;

- (RACSequence *)catch:(RACSequence * (^)(NSError *error))catchBlock;

- (RACSequence *)executeCommand:(RACCommand *)command;

- (RACSequence *)startWith:(id)value;

- (RACSequence *)buffer:(NSUInteger)count;

- (RACSequence *)window:(NSUInteger)count;

@end
