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
@protocol RACSubscribable;

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

// Evaluates the full sequence on the given scheduler.
//
// Returns a subscribable which sends the receiver's values on the given
// scheduler as they're evaluated.
- (id<RACSubscribable>)subscribableWithScheduler:(RACScheduler *)scheduler;

// Returns a sequence that lazily invokes the given blocks to provide head and
// tail. `headBlock` must not be nil.
+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

@end
