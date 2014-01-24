//
//  RACRemovalMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACMinusMutation.h"
#import "RACOrderedCollectionMutation.h"

/// Removes objects from an ordered collection at specific indexes.
@interface RACRemovalMutation : RACMinusMutation <RACOrderedCollectionMutation>

/// The indexes from which `objects` should be removed.
@property (nonatomic, copy, readonly) NSIndexSet *indexes;

/// Initializes a mutation that will remove `objects` at `indexes` in an ordered
/// collection.
///
/// objects - The objects to remove. This array is required, in case the
///           mutation is applied to an unordered collection.
/// indexes - The indexes of the objects to remove. There must be as many
///           indexes as there are `objects`.
- (instancetype)initWithObjects:(NSArray *)objects indexes:(NSIndexSet *)indexes;

@end
