//
//  RACSettingMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSettingMutation.h"

@implementation RACSettingMutation

- (NSIndexSet *)indexes {
	return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.addedObjects.count)];
}

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_replaceAllObjects:self.addedObjects];
}

- (void)mutateOrderedCollection:(id<RACCollection>)collection {
	[self mutateCollection:collection];
}

@end
