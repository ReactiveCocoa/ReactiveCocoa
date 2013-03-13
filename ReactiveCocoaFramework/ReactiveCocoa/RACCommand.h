//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/RACSignal.h>

// A command is a signal triggered in response to some action, typically
// UI-related.
//
// Each `next` sent by a RACCommand corresponds to a value passed to -execute:.
@interface RACCommand : RACSignal

// Whether or not this command can currently execute.
//
// This property will be NO if:
//
// - The command was created with a `canExecuteSignal`, and the latest value
//   sent on the signal was NO, or
// - `allowsConcurrentExecution` is NO and `executing` is YES.
//
// It will be YES in all other cases.
//
// This property is both KVO- and KVC-compliant.
@property (atomic, readonly) BOOL canExecute;

// Whether the command allows multiple invocations of -execute: to proceed
// concurrently.
//
// The default value for this property is NO.
@property (atomic) BOOL allowsConcurrentExecution;

// Whether the command is currently executing.
//
// This will be YES while any thread is running the -execute: method, or while
// any signal returned from -addSignalBlock: has not yet finished.
@property (atomic, getter = isExecuting, readonly) BOOL executing;

// A signal of NSErrors received from all of the signals returned from
// -addSignalBlock:, delivered onto the main thread.
//
// Note that the NSErrors on this signal are sent as `next` events, _not_
// `error` events (which would terminate any subscriptions).
//
// This can be used, for example, to show an alert whenever an error occurs in
// the asynchronous work triggered by the command.
@property (nonatomic, strong, readonly) RACSignal *errors;

// Creates a command that can always be executed.
+ (instancetype)command;

// Creates a command and initializes it with -initWithCanExecuteSignal:.
+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal;

// Initializes a command that can be executed conditionally.
//
// This is the designated initializer for this class.
//
// canExecuteSignal - A signal of BOOLs which indicate whether the command
//                    should be enabled. `canExecute` will be based on the latest
//                    value sent from this signal. Before any values are sent,
//                    `canExecute` will default to YES. This argument may be
//                    nil.
//
// Returns the initialized command.
- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal;

// Adds a block to invoke each time the receiver is executed.
//
// signalBlock - A block that returns a signal. The returned signal must not be
//               nil, and will be subscribed to synchronously from -execute:. If
//               the returned signal errors out, the `NSError` will be sent as
//               a value on `errors`. `executing` will remain YES until the
//               returned signal completes or errors. This argument must not be
//               nil.
//
// Returns a signal of the signals returned from successive invocations of
// `signalBlock`. Each individual signal will be multicast to a replay subject.
- (RACSignal *)addSignalBlock:(RACSignal * (^)(id value))signalBlock;

// If `canExecute` is YES, this method will:
//
// - Set `executing` to YES.
// - Send `value` to the receiver's subscribers.
// - Execute each block added with -addSignalBlock: and subscribe to all of
//   the returned signals.
// - Once all the signals returned from the `signalBlock`s have completed or
//   errored, set `executing` back to NO.
//
// Returns whether the command executed (i.e., whether `canExecute` was YES).
- (BOOL)execute:(id)value;

@end

@interface RACCommand (Deprecated)

- (void)sendNext:(id)value __attribute__((deprecated("Commands should not be manually controlled")));
- (void)sendError:(NSError *)error __attribute__((deprecated("Commands should not be manually controlled")));
- (void)sendCompleted __attribute__((deprecated("Commands should not be manually controlled")));
- (void)didSubscribeWithDisposable:(RACDisposable *)disposable __attribute__((deprecated("Commands should not be manually controlled")));
+ (instancetype)subject __attribute__((deprecated("Use +command instead")));

@end
