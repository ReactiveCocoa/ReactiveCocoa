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

// Creates and returns a new background scheduler with the given priority and
// name. The name is for debug and instrumentation purposes only.
//
// Scheduler creation is cheap. It's unnecessary to save the result of this
// method call unless you want to serialize some actions on the same background
// scheduler.
+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority name:(NSString *)name;

// Invokes +schedulerWithPriority:name: with a default name.
+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority;

// Invokes +schedulerWithPriority: with RACSchedulerPriorityDefault.
+ (instancetype)scheduler;

// Creates a new scheduler with the given queue and name.
//
// Note that the scheduler can only ensure the serial execution of blocks
// scheduled through this scheduler and not blocks enqueued directly on the
// given queue, or even blocks scheduled on the same queue through a different
// scheduler. If the queue allows for concurrent execution, scheduled blocks may
// run concurrently with blocks directly enqueued.
//
// queue - The queue which the scheduler should target. Cannot be NULL.
// name  - The name for the scheduler, to be used for debug or instrumentation
//         purposes only. May be nil.
//
// Returns the created scheduler.
+ (instancetype)schedulerWithQueue:(dispatch_queue_t)queue name:(NSString *)name;

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

// Schedule the given block for execution on the scheduler at or after
// a specific time.
//
// Note that blocks scheduled for a certain time will not preempt any other
// scheduled work that is executing at the time.
//
// When invoked on the +immediateScheduler, the calling thread **will block**
// until the specified time.
//
// when  - The earliest time at which `block` should begin executing. The block
//         may not execute immediately at this time, whether due to system load
//         or another block on the scheduler currently being run.
// block - The block to schedule for execution. Cannot be nil.
//
// Returns a disposable which can be used to cancel the scheduled block before
// it begins executing, or nil if cancellation is not supported.
- (RACDisposable *)after:(dispatch_time_t)when schedule:(void (^)(void))block;

// Schedule the given block for execution on the scheduler after the delay.
//
// Converts seconds to nanoseconds and calls `-after:schedule:`.
- (RACDisposable *)afterDelay:(NSTimeInterval)delay schedule:(void (^)(void))block;

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
