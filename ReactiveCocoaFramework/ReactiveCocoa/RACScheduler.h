//
//  RACScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RACScheduler : NSObject

// Create a new scheduler with the given schedule block. The schedule block will get called by -schedule: with the block it is given. The schedule block should then schedule that block to be performed.
// This makes it easier to create a custom scheduler without having to subclass.
+ (id)schedulerWithScheduleBlock:(void (^)(void (^block)(void)))scheduleBlock;

// A singleton scheduler that immediately performs blocks.
+ (id)immediateScheduler;

// A singleton scheduler that performs blocks in the main queue.
+ (id)mainQueueScheduler;

// A singleton scheduler that performs blocks asynchronously in a background queue.
+ (id)backgroundScheduler;

// A singleton scheduler that performs blocks asynchronously in the current queue.
+ (id)deferredScheduler;

// Schedule the given block for execution on the scheduler. The default implementation just calls the schedule block if the scheduler was created with one.
- (void)schedule:(void (^)(void))block;

@end
