//
//  RACPromise.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACScheduler;
@class RACSignal;
@protocol RACSubscriber;

/// Represents work that is guaranteed ("promised") to execute _exactly_ once
/// when started, until success or failure occurs.
///
/// Lazy signals can be turned into promises using -[RACSignal promise].
@interface RACPromise : NSObject

/// Creates a promise which will run `block` on the given scheduler.
///
/// scheduler - The scheduler upon which to enqueue the work of the promise.
///             This must not be nil.
/// block     - The block to run, this block will be given a subscriber that it
///             should send events to. When execution finishes, a `completed` or
///             `error` event should be sent to `subscriber`. This block must
///             not be nil.
///
/// Returns an unstarted promise.
+ (instancetype)promiseWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block;

/// Immediately starts the work of the receiver, if it hasn't already begun.
///
/// Once started, the promise's work cannot be canceled.
///
/// Returns a signal which will send the results of the work. If the receiver
/// is already executing, or has already finished, any existing results will be
/// sent on the returned signal.
- (RACSignal *)start;

/// Invokes -start when the returned signal is first subscribed to.
- (RACSignal *)deferred;

- (id)init __attribute__((unavailable("Use +promiseWithScheduler:block: or -[RACSignal promiseOnScheduler:] instead")));

@end
