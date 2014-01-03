//
//  RACReplacementMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACOrderedCollectionMutation.h"

/// Replaces objects in an ordered collection at specific indexes.
@interface RACReplacementMutation : NSObject <RACOrderedCollectionMutation>

/// The indexes at which to perform replacements.
@property (nonatomic, copy, readonly) NSIndexSet *indexes;

/// The objects to be replaced.
@property (nonatomic, copy, readonly) NSArray *removedObjects;

/// The objects to be inserted.
@property (nonatomic, copy, readonly) NSArray *addedObjects;

/// Initializes a mutation that will replace `removedObjects` with
/// `addedObjects` at `indexes` in an ordered collection.
///
/// removedObjects - The objects to remove. This array is required, in case the
///                  mutation is applied to an unordered collection.
/// addedObjects   - The objects to replace `removedObjects` with.
/// indexes        - The indexes of the objects to be replaced. There must be as
///                  many indexes as there are `removedObjects` and
///                  `addedObjects`.
- (instancetype)initWithRemovedObjects:(NSArray *)removedObjects addedObjects:(NSArray *)addedObjects indexes:(NSIndexSet *)indexes;

@end
