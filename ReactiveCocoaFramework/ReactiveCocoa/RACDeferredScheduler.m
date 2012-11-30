//
//  RACDeferredScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeferredScheduler.h"
#import "RACScheduler+Private.h"

@implementation RACDeferredScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.deferredScheduler"];
}

#pragma mark RACScheduler

- (void)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	RACScheduler *currentScheduler = RACScheduler.currentScheduler ?: RACScheduler.mainThreadScheduler;
	[currentScheduler schedule:block];
}

@end
