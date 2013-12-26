//
//  RACMinusMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCollectionMutation.h"

@interface RACMinusMutation : NSObject <RACCollectionMutation>

@property (nonatomic, copy, readonly) NSArray *removedObjects;

@end
