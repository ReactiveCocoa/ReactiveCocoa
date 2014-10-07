//
//  RACTupleSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

// Private class that adapts a RACTuple to the RACSequence interface.
@interface RACTupleSequence : RACSequence

// Returns a sequence for enumerating over the given backing array (from a
// RACTuple), starting from the given offset.
+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset;

@end
