#import "RACScheduler.h"

/// A scheduler which runs scheduled work in order on an underlying scheduler.
///
/// When not specified, the underlying scheduler defaults to the immediate scheduler.
///
/// This scheduler can be used as a synchronization primitive, like a lock that queues instead of blocking.
@interface RACInOrderScheduler : RACScheduler

/// Initializes the receiving RACInOrderScheduler to run scheduled blocks as immediately as possible.
- (instancetype)init;

/// Initializes the receiving RACInOrderScheduler to run scheduled blocks on the given scheduler.
- (instancetype)initWithScheduler:(RACScheduler*)scheduler;

/// Returns a new RACInOrderScheduler, initialized to run scheduled blocks on the given scheduler.
+ (RACInOrderScheduler *)inOrderSchedulerOnScheduler:(RACScheduler*)scheduler;

@end
