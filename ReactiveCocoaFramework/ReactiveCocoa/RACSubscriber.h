//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACCompoundDisposable;

/// Represents any object which can directly receive values from a RACSignal.
///
/// You generally shouldn't need to implement this protocol. +[RACSignal
/// create:] or -[RACSignal connect:] should work for most uses.
///
/// Implementors of this protocol may receive messages and values from multiple
/// threads simultaneously, and so should be thread-safe. Subscribers will also
/// be weakly referenced so implementations must allow that.
@protocol RACSubscriber <NSObject>
@required

/// The subscriber's disposable.
///
/// When the receiver is connected to a signal, the disposable representing
/// that connection should be added to this compound disposable.
///
/// A subscriber may receive multiple disposables if it gets connected to
/// multiple signals; however, `error` or `completed` events from any
/// connection must terminate _all_ of them.
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

/// Sends the next value to subscribers.
///
/// value - The value to send. This can be `nil`.
- (void)sendNext:(id)value;

/// Sends the error to subscribers.
///
/// error - The error to send. This can be `nil`.
///
/// This terminates the connection, and invalidates the subscriber (such that
/// it cannot connect to anything else in the future).
- (void)sendError:(NSError *)error;

/// Sends completed to subscribers.
///
/// This terminates the connection, and invalidates the subscriber (such that
/// it cannot connect to anything else in the future).
- (void)sendCompleted;

@end
