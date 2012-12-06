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

// A singleton scheduler that flattens and defers recursion.
//
// The behavior of scheduling a block depends on which scheduler the calling
// code is running from:
//
//  - If the caller isn't running on a scheduler, the block is scheduled on the
//    +mainThreadScheduler.
//  - If the caller is running on any scheduler other than the
//    +iterativeScheduler, the block is executed immediately.
//  - Otherwise, if the caller was scheduled using the +iterativeScheduler, the
//    block is scheduled on the +currentScheduler, and will execute only _after_
//    the calling block completes.
//
// This should be used when you want to execute something as soon as possible,
// unless it would recurse. It prevents the possibility of stack overflow in
// deeply nested scheduling.
//
// **Note:** Unlike most other schedulers, this does not set the current
// scheduler to itself. However, because of the semantics defined above, there
// is guaranteed to always be a +currentScheduler for scheduled blocks.
+ (instancetype)iterativeScheduler;

// A singleton scheduler that executes blocks in the main thread.
+ (instancetype)mainThreadScheduler;

// Creates and returns a new scheduler with the given priority.
+ (instancetype)newBackgroundSchedulerWithPriority:(RACSchedulerPriority)priority;

// Creates and returns a new scheduler with the default priority.
+ (instancetype)newBackgroundScheduler;

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
//                  which will reschedule the recursive block for execution
//                  immediately after the current iteration. This passed-in
//                  block will automatically skip scheduling if the scheduling
//                  of the `recursiveBlock` was disposed in the meantime.
//
// Returns a disposable which can be used to cancel the scheduled block before
// it begins executing, or to stop it from continuing to recurse if it's already
// begun execution.
- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock;

@end
