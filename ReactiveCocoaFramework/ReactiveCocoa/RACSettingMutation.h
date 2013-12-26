//
//  RACSettingMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"
#import "RACOrderedCollectionMutation.h"

@interface RACSettingMutation : NSObject <RACCollectionMutation, RACOrderedCollectionMutation>

@property (nonatomic, copy, readonly) NSArray *addedObjects;

- (instancetype)initWithObjects:(NSArray *)objects;

@end
