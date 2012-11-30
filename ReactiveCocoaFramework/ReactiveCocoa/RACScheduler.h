//
//  RACScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;

// Schedulers are used to control when and in which queue work is performed.
@interface RACScheduler : NSObject

// A singleton scheduler that immediately executes the blocks it is given.
//
// Note that unlike most other schedulers, this does not set the current
// scheduler.
+ (instancetype)immediateScheduler;

// A singleton schedule like +immediateScheduler, with one important caveat. If
// called within another +currentQueueScheduler scheduled block, it will enqueue
// the new block to be executed after the current block completes, as opposed to
// executing it immediately. This is used to flatten possibly deep recursion.
+ (instancetype)currentQueueScheduler;

// A singleton scheduler that executes blocks in the main queue.
+ (instancetype)mainQueueScheduler;

// A singleton scheduler that executes blocks in GCD's default priority global
// queue.
+ (instancetype)sharedBackgroundScheduler;

// A singleton scheduler that executes blocks in the current scheduler. If the
// current scheduler cannot be determined, it uses the main queue scheduler.
+ (instancetype)deferredScheduler;

// Creates and returns a new scheduler which executes blocks in a background
// queue.
+ (instancetype)backgroundScheduler;

// The current scheduler. This will only be valid when used from within a
// -[RACScheduler schedule:] block.
+ (instancetype)currentScheduler;

// Schedule the given block for execution on the scheduler.
//
// Scheduled blocks will be executed in the order in which they were scheduled.
//
// block - The block to schedule for execution. Cannot be nil.
//
// Returns a disposable which can be disposed of to cancel the execution of the
// block.
- (RACDisposable *)schedule:(void (^)(void))block;

@end
