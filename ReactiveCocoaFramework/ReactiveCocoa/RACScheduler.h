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

// Scheduled with -scheduleRecursiveBlock:, this type of block is passed a block
// with which it can call itself recursively.
typedef void (^RACSchedulerRecursiveBlock)(void (^reschedule)(void));

@class RACDisposable;

// Schedulers are used to control when and where work is performed.
@interface RACScheduler : NSObject

// A singleton scheduler that immediately executes the blocks it is given.
//
// **Note:** Unlike most other schedulers, this does not set the current
// scheduler. There may still be a valid +currentScheduler if this is used
// within a block scheduled on a different scheduler.
+ (instancetype)immediateScheduler;

// A singleton scheduler that executes blocks in the main thread.
+ (instancetype)mainThreadScheduler;

// Creates and returns a new background scheduler with the given priority.
//
// Scheduler creation is cheap. It's unnecessary to save the result of this
// method call unless you want to serialize some actions on the same background
// scheduler.
+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority;

// Invokes +schedulerWithPriority: with RACSchedulerPriorityDefault.
+ (instancetype)scheduler;

// The current scheduler. This will only be valid when used from within a
// -[RACScheduler schedule:] block or when on the main thread.
+ (instancetype)currentScheduler;

// Schedule the given block for execution on the scheduler.
//
// Scheduled blocks will be executed in the order in which they were scheduled.
//
// block - The block to schedule for execution. Cannot be nil.
//
// Returns a disposable which can be used to cancel the scheduled block before
// it begins executing, or nil if cancellation is not supported.
- (RACDisposable *)schedule:(void (^)(void))block;

// Schedule the given recursive block for execution on the scheduler. The
// scheduler will automatically flatten any recursive scheduling into iteration
// instead, so this can be used without issue for blocks that may keep invoking
// themselves forever.
//
// Scheduled blocks will be executed in the order in which they were scheduled.
//
// recursiveBlock - The block to schedule for execution. When invoked, the
//                  recursive block will be passed a `void (^)(void)` block
//                  which will reschedule the recursive block at the end of the
//                  receiver's queue. This passed-in block will automatically
//                  skip scheduling if the scheduling of the `recursiveBlock`
//                  was disposed in the meantime.
//
// Returns a disposable which can be used to cancel the scheduled block before
// it begins executing, or to stop it from rescheduling if it's already begun
// execution.
- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock;

@end
