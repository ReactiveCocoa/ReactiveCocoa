//
//  RACQueueScheduler+Subclass.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueueScheduler.h"

// An interface for use by subclasses.
//
// Subclasses should use `-performAsCurrentScheduler:` to do the actual block
// invocation so that +[RACScheduler currentScheduler] behaves as expected.
//
// **Note that RACSchedulers are expected to be serial**. Subclasses must honor
// that contract. See `RACTargetQueueScheduler` for a queue-based scheduler
// which will enforce the serialization guarantee.
@interface RACQueueScheduler ()

// The queue on which blocks are enqueued.
@property (nonatomic, readonly) dispatch_queue_t queue;

// Initializes the receiver with the name of the scheduler and the queue which
// the scheduler should use.
//
// name  - The name of the scheduler. If nil, a default name will be used.
// queue - The queue upon which the receiver should enqueue scheduled blocks.
//         This argument must not be NULL.
//
// Returns the initialized object.
- (id)initWithName:(NSString *)name queue:(dispatch_queue_t)queue;

// Performs the given block with the receiver as the current scheduler for
// `queue`. This should only be called by subclasses to perform scheduled blocks
// on their queue.
//
// block - The block to execute. Cannot be NULL.
- (void)performAsCurrentScheduler:(void (^)(void))block;

// Converts a date into a GCD time using dispatch_walltime().
//
// date - The date to convert. This must not be nil.
+ (dispatch_time_t)wallTimeWithDate:(NSDate *)date;

@end
