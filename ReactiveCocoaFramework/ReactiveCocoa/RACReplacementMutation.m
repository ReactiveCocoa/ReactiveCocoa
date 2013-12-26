//
//  RACReplacementMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACReplacementMutation.h"

@implementation RACReplacementMutation

#pragma mark Properties

@synthesize indexes = _indexes;

#pragma mark Lifecycle

- (instancetype)initWithRemovedObjects:(NSArray *)removedObjects addedObjects:(NSArray *)addedObjects indexes:(NSIndexSet *)indexes {
	NSCParameterAssert(removedObjects != nil);
	NSCParameterAssert(addedObjects != nil);
	NSCParameterAssert(indexes != nil);
	NSCParameterAssert(removedObjects.count == indexes.count);
	NSCParameterAssert(addedObjects.count == indexes.count);

	self = [super init];
	if (self == nil) return nil;

	_removedObjects = [removedObjects copy];
	_addedObjects = [addedObjects copy];
	_indexes = [indexes copy];

	return self;
}

#pragma mark RACCollectionMutation

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_removeObjects:self.removedObjects];
	[collection rac_addObjects:self.addedObjects];
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_replaceObjectsAtIndexes:self.indexes withObjects:self.addedObjects];
}

@end
