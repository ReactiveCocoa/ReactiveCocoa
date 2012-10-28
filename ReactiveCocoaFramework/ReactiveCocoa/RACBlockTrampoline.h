//
//  RACBlockTrampoline.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Allows a certain subset of dynamic block invocation.
@interface RACBlockTrampoline : NSObject

// Invokes the given block with the given arguments. The block must accept all
// object arguments.
//
// block - The block to invoke. Must accept all object arguments and return an
//         object. Cannot be nil.
// arguments - The arguments with which to invoke the block. `RACTupleNil`s will
//             be passed as nils.
//
// Returns the return value of invoking the block.
+ (id)invokeBlock:(id)block withArguments:(NSArray *)arguments;

@end
