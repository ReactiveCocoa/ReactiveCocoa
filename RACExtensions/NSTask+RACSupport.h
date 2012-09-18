//
//  NSTask+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACCancelableSubscribable;
@class RACSubscribable;
@class RACCancelableSubscribable;
@class RACScheduler;

extern NSString * const NSTaskRACSupportErrorDomain;

// The NSData from the standard output.
extern NSString * const NSTaskRACSupportOutputData;

// The NSData from the standard error.
extern NSString * const NSTaskRACSupportErrorData;

// The NSString created from the output data. May be nil if a string couldn't
// be made from the data.
extern NSString * const NSTaskRACSupportOutputString;

// The NSString created from the error data. May be nil if a string couldn't
// be made from the data.
extern NSString * const NSTaskRACSupportErrorString;

// An NSArray of the task's arguments.
extern NSString * const NSTaskRACSupportTaskArguments;

// The task itself.
extern NSString * const NSTaskRACSupportTask;

extern const NSInteger NSTaskRACSupportNonZeroTerminationStatus;


@interface NSTask (RACSupport)

// Returns a subscribable to the standard output. Does not start the task.
- (RACSubscribable *)rac_standardOutputSubscribable;

// Returns a subscribable to the standard error. Does not start the task.
- (RACSubscribable *)rac_standardErrorSubscribable;

// Returns a subscribable that sends a +[RACUnit defaultUnit] and completes when
// the task completes.
- (RACSubscribable *)rac_completionSubscribable;

// Runs the task asychronously on the main queue. It aggregates all the data 
// from standard output and sends it once the task completes, scheduled on the
// given scheduler. If the task exists with a non-zero status, it sends an 
// error. The error's userInfo contains objects of the keys 
// NSTaskRACSupportOutputData, NSTaskRACSupportErrorData, and NSTaskRACSupportTask.
//
// scheduler - cannot be nil.
- (RACCancelableSubscribable *)rac_runWithScheduler:(RACScheduler *)scheduler;

// Calls -rac_runWithScheduler: with the immediate scheduler.
- (RACCancelableSubscribable *)rac_run;

@end
