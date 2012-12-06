//
//  RACIterativeScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACIterativeScheduler.h"
#import "RACScheduler+Private.h"

// A key for NSThread.threadDictionary, associated with a boolean NSNumber
// indicating whether the current code was scheduled using the
// +iterativeScheduler.
static NSString * const RACRunningOnIterativeSchedulerKey = @"RACRunningOnIterativeSchedulerKey";

@implementation RACIterativeScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.iterativeScheduler"];
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	void (^schedulingBlock)(void) = ^{
		NSNumber *wasOnIterativeScheduler = NSThread.currentThread.threadDictionary[RACRunningOnIterativeSchedulerKey] ?: @NO;
		NSThread.currentThread.threadDictionary[RACRunningOnIterativeSchedulerKey] = @YES;

		block();

		NSThread.currentThread.threadDictionary[RACRunningOnIterativeSchedulerKey] = wasOnIterativeScheduler;
	};

	BOOL isOnIterativeScheduler = [NSThread.currentThread.threadDictionary[RACRunningOnIterativeSchedulerKey] boolValue];
	if (isOnIterativeScheduler) {
		NSAssert(RACScheduler.currentScheduler != nil, @"+currentScheduler should never be nil when already on the +iterativeScheduler");
		return [RACScheduler.currentScheduler schedule:schedulingBlock];
	}
	
	if (RACScheduler.currentScheduler == nil) {
		return [RACScheduler.mainThreadScheduler schedule:schedulingBlock];
	}

	schedulingBlock();
	return nil;
}

@end
