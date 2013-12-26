//
//  RACInsertionMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACInsertionMutation.h"

@implementation RACInsertionMutation

@synthesize indexes = _indexes;

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_insertObjects:self.addedObjects atIndexes:self.indexes];
}

@end
