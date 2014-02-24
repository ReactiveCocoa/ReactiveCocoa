#import <Foundation/Foundation.h>
#import "RACSubscriber.h"

/// RACSlimSubscriber is a subscriber that delegates calls to the given blocks,
/// and does nothing else.
///
/// (i.e. no synchronization, no retaining, no internal nilling on completion,
/// no detecting notifications arriving after completion)
@interface RACSlimSubscriber : NSObject<RACSubscriber>

/// Initializes the receiving RACSlimSubscriber to delegate to the given blocks.
/// nil arguments will be replaced with blocks that do nothing.
-(instancetype)initWithNext:(void(^)(id))onNext
				   andError:(void(^)(NSError* error))onError
			   andCompleted:(void(^)(void))onCompleted
		andDidSubscribeWith:(void(^)(RACDisposable* disposable))didSubscribeWithDisposable;

/// Initializes the receiving RACSlimSubscriber to do nothing.
-(instancetype) init;

/// Returns a new RACSlimSubscriber that delegates to the given blocks.
/// nil arguments will be replaced with blocks that do nothing.
+(RACSlimSubscriber*) slimSubscriberWithNext:(void(^)(id x))onNext
									andError:(void(^)(NSError* error))onError
								andCompleted:(void(^)(void))onCompleted
						 andDidSubscribeWith:(void(^)(RACDisposable* disposable))didSubscribeWithDisposable;

/// Returns a RACSlimSubscriber that just delegates calls to the
/// given subscriber.
///
/// If the subscriber is already a RACSlimSubscriber, it is just returned. This
/// avoids accumulating indirection when a subscriber is wrapped and tweaked
/// again and again.
+(RACSlimSubscriber*)slimSubscriberWrapping:(id<RACSubscriber>)subscriber;

/// Returns a RACSlimSubscriber with same sendCompleted and sendError blocks,
/// but the given sendNext block.
-(RACSlimSubscriber*)withSendNext:(void(^)(id x))newSendNext;

/// Returns a RACSlimSubscriber with same sendCompleted and sendNext blocks,
/// but the given sendError block.
-(RACSlimSubscriber*)withSendError:(void(^)(NSError* error))newSendError;

/// Returns a RACSlimSubscriber with same sendError and sendNext blocks,
/// but the given sendCompleted block.
-(RACSlimSubscriber*)withSendCompleted:(void(^)(void))newSendCompleted;

@end
