//
//  RACInsertionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACUnionMutation.h"
#import "RACOrderedCollectionMutation.h"

/// Inserts objects into an ordered collection at specific indexes.
@interface RACInsertionMutation : RACUnionMutation <RACOrderedCollectionMutation>

/// The indexes at which the `addedObjects` should be inserted.
@property (nonatomic, copy, readonly) NSIndexSet *indexes;

/// Initializes a mutation that will insert `objects` at `indexes` in an ordered
/// collection.
///
/// objects - The objects to insert.
/// indexes - The indexes at which to insert the `objects`. There must be as many
///           indexes as there are objects.
- (instancetype)initWithObjects:(NSArray *)objects indexes:(NSIndexSet *)indexes;

@end
