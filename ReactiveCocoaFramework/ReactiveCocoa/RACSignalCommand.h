//
//  RACSignalCommand.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACCommand.h>

// A command that starts a signal when executed, passes through its values, and
// cannot be re-executed until the signal completes.
@interface RACSignalCommand : RACCommand

// Whether the command is currently executing.
//
// The command is executing if any thread is currently running the -execute:
// method, or if the signal returned from the receiver's `signalBlock` (passed
// into an initializer) has not yet completed.
//
// `canExecute` will always be NO when this property is YES.
@property (atomic, assign, readonly, getter = isExecuting) BOOL executing;

// A signal of the RACSignals that have been returned from the receiver's
// `signalBlock`.
//
// It is unspecified which thread this signal delivers its events on.
@property (nonatomic, strong, readonly) RACSignal *signalBlockSignal;

// Invokes +commandWithCanExecuteSignal:signalBlock: with a nil
// `canExecuteSignal`.
+ (instancetype)commandWithSignalBlock:(RACSignal * (^)(id sender))signalBlock;

// Creates a command and initializes it using
// -initWithCanExecuteSignal:signalBlock:.
//
// Returns the newly-initialized command.
+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal signalBlock:(RACSignal * (^)(id sender))signalBlock;

// Initializes a command that executes the given block only if enabled.
//
// This is the designated initializer for this class.
//
// canExecuteSignal - A signal of BOOLs which indicate whether the command
//                    should be enabled. `canExecute` will be based on the
//                    latest value sent from this signal. Before any values are
//                    sent, `canExecute` will default to YES. This argument may
//                    be nil.
// signalBlock      - Invoked when the command is executed, this block should
//                    return a signal which performs additional work. The signal
//                    will be subscribed to immediately, but can perform its
//                    work asynchronously. The `sender` argument will be the
//                    object passed to -execute:. This argument may be nil.
//
// Returns the initialized command.
- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal signalBlock:(RACSignal * (^)(id sender))signalBlock;

// If `canExecute` is YES and `executing` is NO, kicks off a new signal.
//
// This will set `executing` to YES, invoke the `signalBlock` given to the
// receiver at the time of initialization, and then send the returned signal on
// `signalBlockSignal`.
//
// Any values or errors sent from the returned signal are forwarded to the
// receiver's subscribers. Once the returned signal completes, `executing` will
// be set back to `NO`.
//
// If `signalBlock` is nil, the receiver will only send `sender` to its
// subscribers, matching the behavior of RACCommand.
//
// Returns whether the command executed.
- (BOOL)execute:(id)sender;

@end
