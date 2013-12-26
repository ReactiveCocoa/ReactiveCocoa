//
//  RACUnionMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACUnionMutation.h"

@implementation RACUnionMutation

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_addObjects:self.addedObjects];
}

@end
