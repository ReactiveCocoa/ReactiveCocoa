//
//  RACMinusMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACMinusMutation.h"

@implementation RACMinusMutation

#pragma mark Lifecycle

- (instancetype)initWithObjects:(NSArray *)objects {
	NSCParameterAssert(objects != nil);

	self = [super init];
	if (self == nil) return nil;

	_removedObjects = [objects copy];

	return self;
}

#pragma mark RACCollectionMutation

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_removeObjects:self.removedObjects];
}

@end
