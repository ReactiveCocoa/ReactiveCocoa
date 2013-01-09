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

// Whether or not this command can currently execute. If the command was created
// with a `canExecuteSignal, this will be the latest value sent on that signal.
// Otherwise, this will always be YES.
//
// This property is both KVO- and KVC-compliant.
@property (readonly) BOOL canExecute;

// Creates a command that can always be executed and has no execution block.
+ (instancetype)command;

// Creates a command that executes the given block.
//
// When using this initializer, `canExecute` will always be YES.
//
// block - A block to invoke when the command is executed. The `sender` argument
//         will be the object passed to -execute:. This argument may be nil.
//
// Returns a new command.
+ (instancetype)commandWithBlock:(void (^)(id sender))block;

// Creates a command and initializes it with -initWithCanExecuteSignal:block:.
+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal block:(void (^)(id sender))block;

// Initializes a command that executes the given block only if enabled.
//
// canExecuteSignal - A signal of BOOLs which indicate whether the command
//                    should be enabled. `canExecute` will match the latest
//                    value sent from this signal. Before any values are sent,
//                    `canExecute` will default to YES. This argument may be
//                    nil.
// block            - A block to invoke when the command is executed. The
//                    `sender` argument will be the object passed to -execute:.
//                    This argument may be nil.
//
// Returns the initialized command.
- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal block:(void (^)(id sender))block;

// If `canExecute` is YES, executes the receiver's block with the given sender,
// then sends `sender` to any subscribers.
//
// Returns whether the command executed (i.e., whether `canExecute` was YES).
- (BOOL)execute:(id)sender;

@end
