//
//  RACSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACStream.h"

// Represents an immutable, lazy sequence of values. Like Cocoa collections,
// sequences cannot contain nil.
//
// Implemented as a class cluster.
@interface RACSequence : NSObject <NSCoding, NSCopying, NSFastEnumeration, RACStream>

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

// Returns a sequence consisting of the objects in the given sequences, lazily
// appended.
+ (RACSequence *)sequenceWithConcatenatedSequences:(NSArray *)seqs;

// Returns the receiver with `obj` prepended to the sequence.
- (RACSequence *)sequenceByPrependingObject:(id)obj;

// Returns all but the first `count` objects in the sequence. If `count` exceeds
// the number of items in the sequence, nil is returned.
- (RACSequence *)drop:(NSUInteger)count;

@end
