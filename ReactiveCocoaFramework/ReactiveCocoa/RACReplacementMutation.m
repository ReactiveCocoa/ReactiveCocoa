//
//  RACReplacementMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACReplacementMutation.h"

@implementation RACReplacementMutation

@synthesize indexes = _indexes;

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_removeObjects:self.removedObjects];
	[collection rac_addObjects:self.addedObjects];
}

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_replaceObjectsAtIndexes:self.indexes withObjects:self.addedObjects];
}

@end
