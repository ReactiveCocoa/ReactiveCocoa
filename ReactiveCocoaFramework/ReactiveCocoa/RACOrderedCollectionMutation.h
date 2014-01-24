//
//  RACOrderedCollectionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"
#import "RACOrderedCollection.h"

/// Represents an in-place change to a <RACOrderedCollection>.
///
/// Any ordered mutation is also a <RACCollectionMutation>, and may be applied
/// in an unordered manner using -mutateCollection:.
@protocol RACOrderedCollectionMutation <RACCollectionMutation>
@required

/// Applies the mutation described by the receiver to the given collection,
/// preserving order.
- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection;

@end
