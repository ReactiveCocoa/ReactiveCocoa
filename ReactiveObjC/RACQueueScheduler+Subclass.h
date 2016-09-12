//
//  RACQueueScheduler+Subclass.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 6/6/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueueScheduler.h"
#import "RACScheduler+Subclass.h"

/// An interface for use by GCD queue-based subclasses.
///
/// See RACScheduler+Subclass.h for subclassing notes.
@interface RACQueueScheduler ()

/// The queue on which blocks are enqueued.
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong, readonly) dispatch_queue_t queue;
#else
// Swift builds with OS_OBJECT_HAVE_OBJC_SUPPORT=0 for Playgrounds and LLDB :(
@property (nonatomic, assign, readonly) dispatch_queue_t queue;
#endif

/// Initializes the receiver with the name of the scheduler and the queue which
/// the scheduler should use.
///
/// name  - The name of the scheduler. If nil, a default name will be used.
/// queue - The queue upon which the receiver should enqueue scheduled blocks.
///         This argument must not be NULL.
///
/// Returns the initialized object.
- (id)initWithName:(NSString *)name queue:(dispatch_queue_t)queue;

/// Converts a date into a GCD time using dispatch_walltime().
///
/// date - The date to convert. This must not be nil.
+ (dispatch_time_t)wallTimeWithDate:(NSDate *)date;

@end
