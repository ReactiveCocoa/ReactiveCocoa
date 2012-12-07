//
//  RACImmediateScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACImmediateScheduler.h"
#import "RACScheduler+Private.h"

@implementation RACImmediateScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.immediateScheduler"];
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	block();
	return nil;
}

@end
