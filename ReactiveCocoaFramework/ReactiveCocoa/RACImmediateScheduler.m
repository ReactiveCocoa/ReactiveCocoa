//
//  RACImmediateScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACImmediateScheduler.h"
#import "EXTScope.h"
#import "RACScheduler+Private.h"

@implementation RACImmediateScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.immediateScheduler"];
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	block();
	return nil;
}

- (RACDisposable *)after:(dispatch_time_t)when schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	// Use a temporary semaphore to block the current thread until a specific
	// dispatch_time_t.
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	dispatch_semaphore_wait(semaphore, when);
	dispatch_release(semaphore);

	block();
	return nil;
}

@end
