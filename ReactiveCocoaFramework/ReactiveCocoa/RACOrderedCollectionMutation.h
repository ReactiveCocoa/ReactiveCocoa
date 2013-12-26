//
//  RACOrderedCollectionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"
#import "RACOrderedCollection.h"

@protocol RACOrderedCollectionMutation <RACCollectionMutation>
@required

@property (nonatomic, copy, readonly) NSIndexSet *indexes;

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection;

@end
