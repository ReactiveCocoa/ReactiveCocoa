//
//  RACMoveMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACOrderedCollectionMutation.h"

@interface RACMoveMutation : NSObject <RACOrderedCollectionMutation>

@property (nonatomic, assign, readonly) NSUInteger fromIndex;
@property (nonatomic, assign, readonly) NSUInteger toIndex;

- (instancetype)initWithFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

@end
