//
//  RACOrderedCollection.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"

@protocol RACOrderedCollection <RACCollection>
@required

/// Inserts the given objects at the given indexes.
- (void)rac_insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexSet;

/// Removes objects from the given indexes in the receiver.
///
/// All indexes must be in bounds.
- (void)rac_removeObjectsAtIndexes:(NSIndexSet *)indexSet;

/// Replaces the objects at the given indexes with the given new objects.
///
/// All indexes must be in bounds.
- (void)rac_replaceObjectsAtIndexes:(NSIndexSet *)indexSet withObjects:(NSArray *)objects;

@end
