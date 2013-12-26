//
//  RACUnionMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACUnionMutation.h"

@implementation RACUnionMutation

#pragma mark Lifecycle

- (instancetype)initWithObjects:(NSArray *)objects {
	NSCParameterAssert(objects != nil);

	self = [super init];
	if (self == nil) return nil;

	_addedObjects = [objects copy];

	return self;
}

#pragma mark RACCollectionMutation

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_addObjects:self.addedObjects];
}

@end
