//
//  RACMoveMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACOrderedCollectionMutation.h"

/// Moves an object between indexes in an ordered collection.
///
/// This mutation is a no-op when applied to a collection using
/// -mutateCollection:.
@interface RACMoveMutation : NSObject <RACOrderedCollectionMutation>

/// The index from which the object should be moved.
@property (nonatomic, assign, readonly) NSUInteger fromIndex;

/// The index to which the object should be moved.
@property (nonatomic, assign, readonly) NSUInteger toIndex;

/// Initializes a mutation that will move an object between `fromIndex` and
/// `toIndex`.
- (instancetype)initWithFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
