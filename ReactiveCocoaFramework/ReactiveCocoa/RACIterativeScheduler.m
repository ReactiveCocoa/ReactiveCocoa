//
//  RACIterativeScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACIterativeScheduler.h"
#import "RACScheduler+Private.h"

// The key for the thread-local block queue.
static NSString * const RACIterativeSchedulerQueue = @"RACIterativeSchedulerQueue";

@implementation RACIterativeScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.iterativeScheduler"];
}

#pragma mark RACScheduler

- (void)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	NSMutableArray *queue = NSThread.currentThread.threadDictionary[RACIterativeSchedulerQueue];
	if (queue == nil) {
		queue = [NSMutableArray array];
		NSThread.currentThread.threadDictionary[RACIterativeSchedulerQueue] = queue;

		[queue addObject:block];

		while (queue.count > 0) {
			void (^dequeuedBlock)(void) = queue[0];
			[queue removeObjectAtIndex:0];
			dequeuedBlock();
		}

		[NSThread.currentThread.threadDictionary removeObjectForKey:RACIterativeSchedulerQueue];
	} else {
		[queue addObject:[block copy]];
	}
}

@end
