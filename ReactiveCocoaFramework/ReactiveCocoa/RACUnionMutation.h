//
//  RACUnionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"

/// Combines the contents of two collections.
@interface RACUnionMutation : NSObject <RACCollectionMutation>

/// The objects to add to the collection.
@property (nonatomic, copy, readonly) NSArray *addedObjects;

/// Initializes a mutation that will add `objects` to the contents of
/// a collection.
- (instancetype)initWithObjects:(NSArray *)objects;

@end
