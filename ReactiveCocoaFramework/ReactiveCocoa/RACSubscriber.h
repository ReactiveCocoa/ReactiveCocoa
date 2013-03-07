//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;

// Represents any object which can directly receive values from a RACSignal.
//
// You generally shouldn't need to implement this protocol. +[RACSignal
// createSignal:], RACSignal's subscription methods, or RACSubject should work
// for most uses.
//
// Implementors of this protocol may receive messages and values from multiple
// threads simultaneously, and so should be thread-safe. Subscribers will also
// be weakly referenced so implementations must allow that.
@protocol RACSubscriber <NSObject>
@required

// Send the next value to subscribers.
//
// value - The value to send. This can be `nil`.
- (void)sendNext:(id)value;

// Send the error to subscribers.
//
// error - The error to send. This can be `nil`.
//
// This terminates the subscription, and invalidates the subscriber (such that
// it cannot subscribe to anything else in the future).
- (void)sendError:(NSError *)error;

// Send completed to subscribers.
//
// This terminates the subscription, and invalidates the subscriber (such that
// it cannot subscribe to anything else in the future).
- (void)sendCompleted;

// Sends the subscriber a disposable that represents one of its subscriptions.
//
// A subscriber may receive multiple disposables if it gets subscribed to
// multiple signals; however, any error or completed events must terminate _all_
// subscriptions.
- (void)didSubscribeWithDisposable:(RACDisposable *)disposable;

@end

// A simple block-based subscriber.
//
// You shouldn't need to interact with this class directly. Use
// -[RACSignal subscribeNext:error:completed:] instead.
@interface RACSubscriber : NSObject <RACSubscriber>

// Creates a new subscriber with the given blocks.
+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

@end
