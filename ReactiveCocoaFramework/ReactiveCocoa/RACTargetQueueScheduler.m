//
//  RACTargetQueueScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTargetQueueScheduler.h"

@implementation RACTargetQueueScheduler

#pragma mark Lifecycle

- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
	NSCParameterAssert(targetQueue != NULL);

	dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
	if (queue == NULL) return nil;

	dispatch_set_target_queue(queue, targetQueue);

	self = [super initWithQueue:queue];
	if (self == nil) return nil;

	dispatch_release(queue);

	return self;
}

@end
