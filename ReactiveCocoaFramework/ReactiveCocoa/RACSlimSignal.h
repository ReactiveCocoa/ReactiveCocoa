#import <Foundation/Foundation.h>
#import "RACSignal.h"

/// RACSlimSignal is a signal that delegates subscription calls to the given
/// block, and does nothing else.
///
/// (i.e. no synchronization, no retaining, no internal nilling on completion)
@interface RACSlimSignal : RACSignal

/// Initializes the receiving slim signal to delegate subscribe calls to
/// the given block.
- (instancetype)initWithSubscribe:(RACDisposable *(^)(id<RACSubscriber> subscriber))subscribe;

/// Returns a new slim signal that delegates subscribe calls to
/// the given block.
+ (RACSlimSignal*)slimSignalWithSubscribe:(RACDisposable *(^)(id<RACSubscriber> subscriber))subscribe;

@end
