//
//  RACStream+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"

@interface RACStream ()

// Combines a list of streams using the logic of the given block.
//
// streams - The streams to combine.
// block   - An operator that combines two streams and returns a new one. The
//           returned stream should contain 2-tuples of the streams' combined
//           values.
//
// Returns a combined stream.
+ (instancetype)join:(id<NSFastEnumeration>)streams block:(RACStream * (^)(id, id))block;

@end
