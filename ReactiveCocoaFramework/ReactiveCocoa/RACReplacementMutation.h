//
//  RACReplacementMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACOrderedCollectionMutation.h"

@interface RACReplacementMutation : NSObject <RACOrderedCollectionMutation>

@property (nonatomic, copy, readonly) NSIndexSet *indexes;
@property (nonatomic, copy, readonly) NSArray *removedObjects;
@property (nonatomic, copy, readonly) NSArray *addedObjects;

- (instancetype)initWithRemovedObjects:(NSArray *)removedObjects addedObjects:(NSArray *)addedObjects indexes:(NSIndexSet *)indexes;

@end
