//
//  RACMoveMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACMoveMutation.h"

@implementation RACMoveMutation

#pragma mark Lifecycle

- (instancetype)initWithFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
	NSCParameterAssert(fromIndex != NSNotFound);
	NSCParameterAssert(toIndex != NSNotFound);

	self = [super init];
	if (self == nil) return nil;

	_fromIndex = fromIndex;
	_toIndex = toIndex;

	return self;
}

#pragma mark RACCollectionMutation

- (instancetype)map:(id (^)(id object))block {
	return self;
}

- (void)mutateCollection:(id<RACCollection>)collection {
	// A move doesn't make any sense upon an unordered collection, so consider
	// it a no-op.
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_moveObjectAtIndex:self.fromIndex toIndex:self.toIndex];
}

@end
