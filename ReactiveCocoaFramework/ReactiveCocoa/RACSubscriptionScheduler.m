//
//  RACSubscriptionScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptionScheduler.h"
#import "RACScheduler+Private.h"

@implementation RACSubscriptionScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"];
}

#pragma mark RACScheduler

- (void)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	if (RACScheduler.currentScheduler == nil) {
		[RACScheduler.mainThreadScheduler schedule:block];
	} else {
		block();
	}
}

@end
