//
//  RACTargetedQueueScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACQueueScheduler.h>

// A scheduler which enqueues blocks on a serial queue which targets a queue.
@interface RACTargetedQueueScheduler : RACQueueScheduler

// Initializes a scheduler with a name and a queue which targets the given
// target queue.
//
// name        - The name of the queue which will target `targetQueue`.
// targetQueue - The queue to target. Cannot be NULL.
//
// Returns the initialized object.
- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue;

@end
