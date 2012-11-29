//
//  RACScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Schedulers are used to control when and in which queue RAC work is performed.
@interface RACScheduler : NSObject

// Is this scheduler concurrent?
@property (nonatomic, readonly, getter = isConcurrent) BOOL concurrent;

// A singleton scheduler that immediately performs blocks.
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

- (instancetype)asSerialScheduler;

// Schedule the given block for execution on the scheduler.
- (void)schedule:(void (^)(void))block;

@end
