//
//  RACMinusMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"

/// Removes objects from a collection.
@interface RACMinusMutation : NSObject <RACCollectionMutation>

/// The objects to remove from the collection.
@property (nonatomic, copy, readonly) NSArray *removedObjects;

/// Initializes a mutation that will remove `objects` from the contents of
/// a collection.
- (instancetype)initWithObjects:(NSArray *)objects;

@end
