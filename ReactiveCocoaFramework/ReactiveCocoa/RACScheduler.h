//
//  RACScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;

// Schedulers are used to control when and in which queue RAC work is performed.
@interface RACScheduler : NSObject

// Is this scheduler concurrent?
@property (nonatomic, readonly, getter = isConcurrent) BOOL concurrent;

// A singleton scheduler that immediately performs the blocks it is given, with
// one important caveat. If called within another immediately scheduled block,
// it will enqueue the new block to be performed after the current block
// completes. This is used to flatten possibly deep recursion.
+ (instancetype)immediateScheduler;

// A singleton scheduler that performs blocks asynchronously in the main queue.
+ (instancetype)mainQueueScheduler;

// A singleton scheduler that performs blocks asynchronously in GCD's default
// priority global queue.
+ (instancetype)backgroundScheduler;

// A singleton scheduler that performs blocks asynchronously in the current
// scheduler. If the current scheduler cannot be determined, it uses the main
// queue scheduler.
+ (instancetype)deferredScheduler;

// Creates and returns a new serial scheduler.
+ (instancetype)serialScheduler;

// Creates and returns a new concurrent scheduler.
+ (instancetype)concurrentScheduler;

// The current scheduler. This will only be valid when using from within a
// -[RACScheduler schedule:] block.
+ (instancetype)currentScheduler;

// Returns a serial scheduler based on the concurrent receiver. If the receiver
// is not concurrent, it returns self.
- (instancetype)asSerialScheduler;

// Schedule the given block for execution on the scheduler.
//
// block - The block to schedule for execution. Cannot be nil.
//
// Returns a disposable which can be disposed of to cancel the execution of the
// block.
- (RACDisposable *)schedule:(void (^)(void))block;

@end
