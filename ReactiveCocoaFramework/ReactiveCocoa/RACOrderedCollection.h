//
//  RACOrderedCollection.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"

/// An abstraction of an ordered collection.
@protocol RACOrderedCollection <RACCollection>
@required

/// Inserts the given objects at the given indexes.
- (void)rac_insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexSet;

/// Removes objects from the given indexes in the receiver.
- (void)rac_removeObjectsAtIndexes:(NSIndexSet *)indexSet;

/// Replaces the objects at the given indexes with the given new objects.
- (void)rac_replaceObjectsAtIndexes:(NSIndexSet *)indexSet withObjects:(NSArray *)objects;

/// Moves an object from one index to another.
///
/// Conceptually, this behaves like a removal followed by an insertion.
///
/// fromIndex - The index of the object to move.
/// toIndex   - The index to which the objects should be moved, calculated as if
///             the object has already been removed from the collection.
- (void)rac_moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
