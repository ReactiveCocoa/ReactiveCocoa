//
//  RACSettingMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"
#import "RACOrderedCollectionMutation.h"

/// Completely replaces the contents of a collection with a new collection of
/// objects.
@interface RACSettingMutation : NSObject <RACCollectionMutation, RACOrderedCollectionMutation>

/// The new contents for the collection.
@property (nonatomic, copy, readonly) NSArray *addedObjects;

/// Initializes a mutation that will replace the contents of a collection with
/// `objects`.
- (instancetype)initWithObjects:(NSArray *)objects;

@end
