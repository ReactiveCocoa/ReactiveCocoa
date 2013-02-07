//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/RACSubject.h>

// A command is a signal triggered in response to some action, typically
// UI-related.
//
// Each `next` sent by a RACCommand is the sender which triggered it.
@interface RACCommand : RACSubject

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
//               nil, and will be subscribed to synchronously from -execute:.
//               `executing` will remain YES until the returned signal completes
//               or errors. This argument must not be nil.
//
// Returns a signal of the signals returned from successive invocations of
// `signalBlock`. Each individual signal will be multicast to a replay subject.
- (RACSignal *)addSignalBlock:(RACSignal * (^)(id sender))signalBlock;

// If `canExecute` is YES, this method will:
//
// - Set `executing` to YES.
// - Send `sender` to the receiver's subscribers.
// - Execute each block added with -addSignalBlock: and subscribe to all of
//   the returned signals.
// - Once all the signals returned from the `signalBlock`s have completed or
//   errored, set `executing` back to NO.
//
// Returns whether the command executed (i.e., whether `canExecute` was YES).
- (BOOL)execute:(id)sender;

@end
