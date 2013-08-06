//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSignal.h"

// A command is a signal triggered in response to some action, typically
// UI-related.
@interface RACCommand : NSObject

// A signal of the signals returned by invocations of -execute:.
//
// Upon subscription, this signal will immediately send all in-flight
// executions.
@property (nonatomic, strong, readonly) RACSignal *executionSignals;

// A signal of whether this command is currently executing.
//
// This will send YES whenever -execute: is invoked and the created signal does
// not terminate synchronously. Once all executions have terminated, the signal
// will send NO.
//
// This signal will immediately send YES or NO upon subscription.
@property (nonatomic, strong, readonly) RACSignal *executing;

// Forwards any errors that occur within signals returned by -execute:.
//
// When an error occurs on a signal returned from -execute:, this signal will
// send the associated NSError value as a `next` event (since an `error` event
// would terminate the stream).
@property (nonatomic, strong, readonly) RACSignal *errors;

// A signal of whether this command is able to execute.
//
// This will send NO if:
//
//  - The command was created with an `enabledSignal`, and NO is sent upon that
//    signal, or
//  - `allowsConcurrentExecution` is NO and the command has started executing.
//  - The command is sent a `completed` or `error` event.
//
// Once the above conditions are no longer met, the signal will send YES.
//
// This signal will immediately send YES or NO upon subscription.
@property (nonatomic, strong, readonly) RACSignal *enabled;

// Whether the command allows multiple executions to proceed concurrently.
//
// The default value for this property is NO.
@property (atomic, assign) BOOL allowsConcurrentExecution;

// Invokes -initWithSignalBlock:enabled: with a nil `enabledSignal`.
- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock;

// Initializes a command that is conditionally enabled.
//
// This is the designated initializer for this class.
//
// enabledSignal - A signal of BOOLs which indicate whether the command should
//                 be enabled. `enabled` will be based on the latest value sent
//                 from this signal. Before any values are sent, `enabled` will
//                 default to YES. This argument may be nil.
// signalBlock   - A block which will map each input value (sent to the command as
//                 `next` events or passed to -execute:) to a signal of work.
//                 The returned signal will be multicasted to a replay subject,
//                 sent on `executionSignals`, then subscribed to synchronously.
//                 Neither the block nor the returned signal may be nil.
- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock;

// If the receiver is enabled, this method will:
//
//  1. Invoke the `signalBlock` given at the time of initialization.
//  2. Multicast the returned signal to a RACReplaySubject.
//  3. Send the multicasted signal on `executionSignals`.
//  4. Synchronously subscribe to the original signal.
//
// input - The input value to pass to the receiver's `signalBlock`. This may be
//         nil.
//
// Returns the multicasted signal, after subscription. If the receiver is not
// enabled, nil is returned.
- (RACSignal *)execute:(id)input;

@end
