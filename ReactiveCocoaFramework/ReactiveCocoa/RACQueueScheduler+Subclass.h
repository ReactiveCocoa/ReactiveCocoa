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
@interface RACQueueScheduler (Subclass)

// Performs the given block with the receiver as the current scheduler. This
// should only be used by subclasses to perform scheduled blocks.
//
// block - The block to execute. Cannot be NULL.
- (void)performAsCurrentScheduler:(void (^)(void))block;

@end
