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

// Create a new scheduler with the given schedule block. The schedule block will
// get called by -schedule: with the block it is given. The schedule block
// should then schedule that block to be performed. This makes it easier to
// create a custom scheduler without having to subclass.
+ (instancetype)schedulerWithScheduleBlock:(void (^)(void (^block)(void)))scheduleBlock;

// A singleton scheduler that immediately performs blocks.
+ (instancetype)immediateScheduler;

// A singleton scheduler that performs blocks asynchronously in the main queue.
+ (instancetype)mainQueueScheduler;

// A singleton scheduler that performs blocks asynchronously in GCD's default
// priority global queue.
+ (instancetype)backgroundScheduler;

// A singleton scheduler that performs blocks asynchronously in the current queue.
+ (instancetype)deferredScheduler;

// A singleton scheduler that adds blocks to an operation queue whose max
// concurrent operation count is NSOperationQueueDefaultMaxConcurrentOperationCount.
+ (instancetype)sharedOperationQueueScheduler;

// Creates a new scheduler that adds blocks to an operation queue whose max
// concurrent operation count is NSOperationQueueDefaultMaxConcurrentOperationCount.
+ (instancetype)operationQueueScheduler;

// Creates a new scheduler that adds blocks to the given operation queue.
+ (instancetype)schedulerWithOperationQueue:(NSOperationQueue *)queue;

// Schedule the given block for execution on the scheduler. The default
// implementation just calls the schedule block if the scheduler was created
// with one.
- (void)schedule:(void (^)(void))block;

@end
