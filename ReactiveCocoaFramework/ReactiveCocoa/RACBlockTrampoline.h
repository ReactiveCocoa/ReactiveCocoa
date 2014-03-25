//
//  RACBlockTrampoline.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACTuple;

// A private class that allows a limited type of dynamic block invocation.
@interface RACBlockTrampoline : NSObject

// Invokes the given block with the given arguments. All of the block's
// argument types must be objects and it must be typed to return an object.
//
// At this time, it only supports blocks that take up to 15 arguments. Any more
// is just cray.
//
// block     - The block to invoke. Must accept as many arguments as are given in
//             the arguments array. Cannot be nil.
// arguments - The arguments with which to invoke the block. `RACTupleNil`s will
//             be passed as nils.
//
// Returns the return value of invoking the block.
+ (id)invokeBlock:(id)block withArguments:(RACTuple *)arguments;

@end
