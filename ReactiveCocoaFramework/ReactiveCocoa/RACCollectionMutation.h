//
//  RACCollectionMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"

@protocol RACCollectionMutation <NSObject>
@required

- (void)mutateCollection:(id<RACCollection>)collection;

- (instancetype)map:(id (^)(id object))block;

@end
