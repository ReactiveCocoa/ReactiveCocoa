//
//  RACRemovalMutation.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACMinusMutation.h"
#import "RACOrderedCollectionMutation.h"

@interface RACRemovalMutation : RACMinusMutation <RACOrderedCollectionMutation>
@end
