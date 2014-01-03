//
//  RACInsertionMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACInsertionMutation.h"

#import "NSArray+RACSupport.h"
#import "RACSignal+Operations.h"

@implementation RACInsertionMutation

#pragma mark Lifecycle

- (instancetype)initWithObjects:(NSArray *)objects indexes:(NSIndexSet *)indexes {
	NSCParameterAssert(indexes != nil);
	NSCParameterAssert(indexes.count == objects.count);

	self = [super initWithObjects:objects];
	if (self == nil) return nil;

	_indexes = [indexes copy];

	return self;
}

#pragma mark RACCollectionMutation

- (instancetype)map:(id (^)(id object))block {
	NSArray *newObjects = [[self.addedObjects.rac_signal map:block] array];
	return [[self.class alloc] initWithObjects:newObjects indexes:self.indexes];
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_insertObjects:self.addedObjects atIndexes:self.indexes];
}

@end
