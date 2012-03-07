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

#define rac_synthesize_seq(a) \
	@synthesize a; \
	- (RACSequence *)a { \
		if(a == nil) { \
			a = [RACSequence sequence]; \
		} \
		return a; \
	}


// A sequence is essentially a stream of values. It can be observed and queried.
// It only ever sends the `next` event. It does this when an object is added to the sequence. The added object is passed as the value for the `next` event.
@interface RACSequence : NSObject <RACObservable>

// Creates a new sequence with the default capacity.
+ (id)sequence;

// Creates a new sequence with the given capacity. The capacity dictates how many values are held at once. When the capacity is exceeded, the sequence removes the oldest value.
+ (id)sequenceWithCapacity:(NSUInteger)capacity;

// Adds a new object into the sequence. This will notify observers of this object.
//
// object - the object to insert into the sequence. Cannot be nil.
- (void)addObject:(id)object;

// Returns the last object added to the sequence. May be nil.
- (id)lastObject;

// Convenience method to subscribe to the `next` event.
//
// Returns self to allow for chaining.
- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock;

// Convenience method to subscribe to the `next` and `completed` events.
//
// Returns self to allow for chaining.
- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to the `next`, `completed`, and `error` events.
//
// Returns self to allow for chaining.
- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock error:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `error` events.
- (RACSequence *)subscribeError:(void (^)(NSError *error))errorBlock;

// Convenence method to subscribe to `completed` events.
- (RACSequence *)subscribeCompleted:(void (^)(void))completedBlock;

@end

@interface RACSequence (QueryableImplementations) <RACQueryable>

// Returns a sequence that adds only the objects from the receiver to which `predicate` returns YES.
- (RACSequence *)where:(BOOL (^)(id x))predicate;

// Returns a sequence that adds the objects returned by calling `block` for each object added to the receiver.
- (RACSequence *)select:(id (^)(id x))block;

// Returns a sequence that fires its `next` event only after the receiver hasn't received any new objects for `interval` seconds.
- (RACSequence *)throttle:(NSTimeInterval)interval;

// Returns a sequence that adds an NSArray of the last objects of each sequence each time any an object is added to any of the sequences. If any of the sequences don't have an object, a RACNil is added in its place.
+ (RACSequence *)combineLatest:(NSArray *)sequences;

// Returns a sequence that adds the latest object any time any of the given sequences are added to.
+ (RACSequence *)merge:(NSArray *)sequences;

// Adds the last added object to the given sequence and returns self.
- (RACSequence *)toSequence:(RACSequence *)property;

// Sets the last added object to the value of the given key path and returns self.
- (RACSequence *)toObject:(NSObject *)object keyPath:(NSString *)keyPath;

// Returns a sequence that adds objects from the receiver only if they're not equal to the last added object added to the sequence.
- (RACSequence *)distinctUntilChanged;

// Returns an sequence that adds an NSArray of the last objects of each of the sequence each time an object is added to any of the sequences, *and* there is a last object for each of the sequences.
+ (RACSequence *)zip:(NSArray *)sequences;

// Returns the sequence returned by the block. This can be used to chain different sequences together.
- (RACSequence *)selectMany:(RACSequence * (^)(RACSequence *x))selectMany;

// Returns a sequence that only sends its `next` after the receiver has received `count` objects.
- (RACSequence *)take:(NSUInteger)count;

@end
