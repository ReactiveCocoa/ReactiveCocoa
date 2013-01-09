//
//  RACQueueScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACScheduler.h>

// A scheduler which asynchronously enqueues all its work to a private Grand
// Central Dispatch queue.
@interface RACQueueScheduler : RACScheduler

// Initializes the receiver with the name of the scheduler and the queue which
// the scheduler should target.
//
// name        - The name of the scheduler.
// targetQueue - The queue which the scheduler should target. Cannot be NULL.
//
// Returns the initialized object.
- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue;

@end
