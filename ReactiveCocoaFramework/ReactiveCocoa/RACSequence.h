//
//  RACSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACStream.h"

@class RACScheduler;
@class RACSignal;

// Represents an immutable, lazy sequence of values. Like Cocoa collections,
// sequences cannot contain nil.
//
// Most inherited RACStream methods that accept a block will execute the block
// _at most_ once for each value that is evaluated in the returned sequence.
// Side effects are subject to the behavior described in
// +sequenceWithHeadBlock:tailBlock:.
//
// Implemented as a class cluster. A minimal implementation for a subclass
// consists simply of -head and -tail.
@interface RACSequence : RACStream <NSCoding, NSCopying, NSFastEnumeration>

// The first object in the sequence, or nil if the sequence is empty.
//
// Subclasses must provide an implementation of this method.
@property (nonatomic, strong, readonly) id head;

// All but the first object in the sequence, or nil if the sequence is empty.
//
// Subclasses must provide an implementation of this method.
@property (nonatomic, strong, readonly) RACSequence *tail;

// Evaluates the full sequence to produce an equivalently-sized array.
@property (nonatomic, copy, readonly) NSArray *array;

// Invokes -signalWithScheduler: with a new RACScheduler.
- (RACSignal *)signal;

// Evaluates the full sequence on the given scheduler.
//
// Each item is evaluated in its own scheduled block, such that control of the
// scheduler is yielded between each value.
//
// Returns a signal which sends the receiver's values on the given scheduler as
// they're evaluated.
- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler;

// Creates a sequence that dynamically generates its values.
//
// headBlock - Invoked the first time -head is accessed.
// tailBlock - Invoked the first time -tail is accessed.
//
// The results from each block are memoized, so each block will be invoked at
// most once, no matter how many times the head and tail properties of the
// sequence are accessed.
//
// Any side effects in `headBlock` or `tailBlock` should be thread-safe, since
// the sequence may be evaluated at any time from any thread. Not only that, but
// -tail may be accessed before -head, or both may be accessed simultaneously.
// As noted above, side effects will only be triggered the _first_ time -head or
// -tail is invoked.
//
// Returns a sequence that lazily invokes the given blocks to provide head and
// tail. `headBlock` must not be nil.
+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

@end
