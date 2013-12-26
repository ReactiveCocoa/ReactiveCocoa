//
//  RACRemovalMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACRemovalMutation.h"

@implementation RACRemovalMutation

#pragma mark Properties

@synthesize indexes = _indexes;

#pragma mark Lifecycle

- (instancetype)initWithObjects:(NSArray *)objects indexes:(NSIndexSet *)indexes {
	NSCParameterAssert(indexes != nil);
	NSCParameterAssert(indexes.count == objects.count);

	self = [super initWithObjects:objects];
	if (self == nil) return nil;

	_indexes = [indexes copy];

	return self;
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_removeObjectsAtIndexes:self.indexes];
}

@end
