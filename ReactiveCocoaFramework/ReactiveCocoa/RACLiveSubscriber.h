//
//  RACLiveSubscriber.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSubscriber.h"

@class RACSignal;

/// A private subscriber that represents (and listens to) a currently-active
/// subscription to a signal.
///
/// Subscribers of this type don't live past the signal lifetime, and are only
/// used privately (e.g., within -subscribeNext:… and friends).
@interface RACLiveSubscriber : NSObject <RACSubscriber>

/// The signal sending events to this subscriber.
///
/// This property isn't `weak` because it's only used for DTrace probes, so
/// a zeroing weak reference would incur an unnecessary performance penalty in
/// normal usage.
@property (atomic, unsafe_unretained) RACSignal *signal;

/// Creates a subscriber that will forward all of its events to `subscriber`
/// until disposed.
///
/// This is useful to redirect events to a user-provided subscriber, but retain
/// the ability to terminate this individual subscription (without terminating
/// other subscriptions to the same subscriber).
///
/// subscriber - The subscriber to forward events to. This must not be nil.
+ (instancetype)subscriberForwardingToSubscriber:(id<RACSubscriber>)subscriber;

/// Creates a subscriber that invokes the given blocks when signal events occur.
///
/// next      - A block to invoke upon `next` events. This must not be nil.
/// error     - A block to invoke upon `error` events. This must not be nil.
/// completed - A block to invoke upon `completed` events. This must not be nil.
+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

@end
