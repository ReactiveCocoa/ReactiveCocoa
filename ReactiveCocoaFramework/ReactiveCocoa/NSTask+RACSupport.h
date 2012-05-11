//
//  NSTask+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;
@class RACScheduler;

extern NSString * const NSTaskRACSupportErrorDomain;

// The NSData from the standard output.
extern NSString * const NSTaskRACSupportOutputData;

// The NSData from the standard error.
extern NSString * const NSTaskRACSupportErrorData;

// The task itself.
extern NSString * const NSTaskRACSupportTask;

extern const NSInteger NSTaskRACSupportNonZeroTerminationStatus;


@interface NSTask (RACSupport)

// Returns a subscribable to the standard output. Does not start the task.
- (RACSubscribable *)rac_standardOutputSubscribable;

// Returns a subscribable to the standard error. Does not start the task.
- (RACSubscribable *)rac_standardErrorSubscribable;

// Runs the task asynchronously, scheduled with the given scheduler. It 
// aggregates all the data from standard output and sends it once the task 
// completes. If the task exists with a non-zero status, it sends an error. The
// error's userInfo contains objects of the keys NSTaskRACSupportOutputData, 
// NSTaskRACSupportErrorData, and NSTaskRACSupportTask.
//
// scheduler - cannot be nil.
- (RACSubscribable *)rac_runAsyncWithScheduler:(RACScheduler *)scheduler;

// Calls -rac_runAsyncWithScheduler: with the immediate scheduler.
- (RACSubscribable *)rac_runAsync;

@end
