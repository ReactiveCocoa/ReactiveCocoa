//
//  RACDynamicSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"

// A sequence implemented dynamically using blocks.
@interface RACDynamicSequence : RACSequence

// Returns a sequence that lazily invokes the given blocks to provide head and
// tail. `headBlock` must not be nil.
+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock;

// Returns a sequence of `value`, `generatorBlock(value)`,
// `generatorBlock(generatorBlock(value))`, etc.
+ (RACSequence *)sequenceWithGeneratorBlock:(id (^)(id))generatorBlock startingValue:(id)value;

@end
