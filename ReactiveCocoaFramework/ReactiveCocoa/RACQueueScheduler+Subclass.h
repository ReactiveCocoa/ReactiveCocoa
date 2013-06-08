//
//  RACQueueScheduler+Subclass.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACQueueScheduler.h>

// An interface for use by subclasses.
//
// Subclasses should use `-performAsCurrentScheduler:` to do the actual block
// invocation so that +[RACScheduler currentScheduler] behaves as expected.
@interface RACQueueScheduler ()

// The queue on which blocks are enqueued.
@property (nonatomic, readonly) dispatch_queue_t queue;

// Performs the given block with the receiver as the current scheduler for
// `queue`. This should only be called by subclasses to perform scheduled blocks
// on their queue.
//
// block - The block to execute. Cannot be NULL.
- (void)performAsCurrentScheduler:(void (^)(void))block;

@end
