//
//  RACQueueScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACScheduler.h>

// A scheduler which asynchronously enqueues all its work to a Grand Central
// Dispatch queue.
//
// RACQueueScheduler may be subclassed. To subclass, import
// `RACQueueScheduler+Subclass.h` explicitly.
@interface RACQueueScheduler : RACScheduler

// Initializes the receiver with the name of the scheduler and the queue which
// the scheduler should use.
//
// queue - The queue which the scheduler should use. Cannot be NULL.
//
// Returns the initialized object.
- (id)initWithQueue:(dispatch_queue_t)queue;

@end
