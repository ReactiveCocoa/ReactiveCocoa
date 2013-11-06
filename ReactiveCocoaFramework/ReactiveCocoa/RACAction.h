//
//  RACAction.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSignal.h"

/// Represents a UI action which will subscribe to a signal when activated.
///
/// To create an action, invoke -[RACSignal action] on a lazy signal.
@interface RACAction : NSObject

/// A signal of whether this action is currently executing.
///
/// This signal will send its current value immediately, and then all future
/// values on the main thread.
@property (nonatomic, strong, readonly) RACSignal *executing;

/// Forwards errors that occur from subscribing to the receiver's signal.
///
/// When an error occurs during an execution of the receiver, this signal will
/// send the associated NSError value as a `next` event (since an `error` event
/// would terminate the stream).
///
/// This signal will send its values on the main thread.
@property (nonatomic, strong, readonly) RACSignal *errors;

/// Asynchronously executes the receiver from the main thread.
///
/// If the receiver is already executing, nothing happens.
///
/// sender - This argument is currently unused. It exists only so `RACAction`
///          can be bound directly to UI controls.
- (void)execute:(id)sender;

/// Creates a signal which will execute the receiver, if not already executing,
/// upon each subscription.
///
/// If the receiver is already executing when the returned signal is subscribed
/// to, the subscriber will receive all events already sent during the current
/// execution, then any new events afterward.
///
/// Unlike -execute:, this allows you to receive errors directly, instead of via
/// `errors`.
///
/// Disposing of all deferred subscriptions will also dispose of the underlying
/// subscription, as long as no -execute: calls are in progress either.
///
/// Returns a signal which will execute the receiver upon subscription, if not
/// already executing, then forward all events. Existing events are sent
/// immediately, and future events will be sent on their originating thread.
- (RACSignal *)deferred;

- (id)init __attribute__((unavailable("Use -[RACSignal action] instead")));

@end

@interface RACSignal (RACActionAdditions)

/// Creates an action from a signal.
///
/// Returns a RACAction that will subscribe to the receiver on the main thread
/// when executed.
- (RACAction *)action;

@end
