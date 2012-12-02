//
//  RACScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// The priority for the scheduler.
//
// RACSchedulerPriorityHigh       - High priority.
// RACSchedulerPriorityDefault    - Default priority.
// RACSchedulerPriorityLow        - Low priority.
// RACSchedulerPriorityBackground - Background priority.
typedef enum : long {
	RACSchedulerPriorityHigh = DISPATCH_QUEUE_PRIORITY_HIGH,
	RACSchedulerPriorityDefault = DISPATCH_QUEUE_PRIORITY_DEFAULT,
	RACSchedulerPriorityLow = DISPATCH_QUEUE_PRIORITY_LOW,
	RACSchedulerPriorityBackground = DISPATCH_QUEUE_PRIORITY_BACKGROUND,
} RACSchedulerPriority;

@class RACDisposable;

// Schedulers are used to control when and where work is performed.
@interface RACScheduler : NSObject

// A singleton scheduler that immediately executes the blocks it is given.
//
// Note that unlike most other schedulers, this does not set the current
// scheduler. There may still be a valid +currentScheduler if this is used
// within a block scheduled on a different scheduler.
+ (instancetype)immediateScheduler;

// A singleton scheduler like +immediateScheduler, with one important difference.
// If called within another +iterativeScheduler scheduled block, it will enqueue
// the new block to be executed immediately after the current block completes,
// as opposed to executing it immediately within the current block.
//
// This should be used when you want to execute something immediately, unless it
// would recurse. It prevents the possibility of stack overflow in deeply nested
// scheduling.
//
// Note that unlike most other schedulers, this does not set the current
// scheduler. There may still be a valid +currentScheduler if this is used
// within a block scheduled on a different scheduler.
+ (instancetype)iterativeScheduler;

// A singleton scheduler that executes blocks in the main thread.
+ (instancetype)mainThreadScheduler;

// A singleton scheduler that executes blocks in +currentScheduler, after any
// blocks already scheduled have completed. If +currentScheduler is nil, it
// uses +mainThreadScheduler.
+ (instancetype)deferredScheduler;

// Creates and returns a new scheduler with the given priority.
+ (instancetype)backgroundSchedulerWithPriority:(RACSchedulerPriority)priority;

// Creates and returns a new scheduler with the default priority.
+ (instancetype)backgroundScheduler;

// The current scheduler. This will only be valid when used from within a
// -[RACScheduler schedule:] block or when on the main thread.
+ (instancetype)currentScheduler;

// Schedule the given block for execution on the scheduler.
//
// Scheduled blocks will be executed in the order in which they were scheduled.
//
// block - The block to schedule for execution. Cannot be nil.
- (void)schedule:(void (^)(void))block;

@end
