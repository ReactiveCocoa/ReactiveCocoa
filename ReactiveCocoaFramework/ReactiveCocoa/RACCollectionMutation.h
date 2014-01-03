//
//  RACCollectionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"

/// Represents an in-place change to a <RACCollection>.
@protocol RACCollectionMutation <NSObject>
@required

/// Applies the mutation described by the receiver to the given collection.
///
/// Even if the receiver is a <RACOrderedCollectionMutation>, or `collection` is
/// a <RACOrderedCollection>, this method is not guaranteed to preserve ordering.
- (void)mutateCollection:(id<RACCollection>)collection;

/// Transforms each object that will participate in the mutation.
///
/// The exact meaning of this method depends on the specific
/// <RACCollectionMutation> implementation it is applied to.
///
/// block - Maps each object in the receiver to a new object.
///
/// Returns a mutation that will use the objects resulting from `block`.
- (instancetype)map:(id (^)(id object))block;

@end
