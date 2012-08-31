//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACSubject.h"


// A command is a value that allows more customization of its behavior.
// It sends `next` events when the command executes. `next` is sent the value
// passed into `-execute:`.
@interface RACCommand : RACSubject

// Whether or not the command can execute, based on the canExecuteSubscribable
// given when the command was created. If the command was created without
// canExecuteSubscribable, this will always be YES. You should use the
// `-canExecute:` method instead.
@property (readonly, assign) BOOL canExecute;

// Creates a new command with no execute or can execute block.
+ (instancetype)command;

// Creates a new command with the given can execute and execute blocks.
//
// canExecuteBlock - the block that is called to determine if the command may
// execute. It is passed the value that would be passed to `-execute:` if it is
// allowed to execute. Can be nil. If it is nil, `-canExecute:` will always
// return YES.
//
// executeBlock - the block that will be executed when the command is executed.
// It will be passed the object given to `-execute:`.
+ (instancetype)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock;

// Creates a new command with the given can execute subscribable and execute
// blocks.
//
// canExecuteSubscribable - A subscribable that sends NSNumber-wrapped BOOLs.
// The command subscribes to it and sets the `canExecute` property to the
// `boolValue` of the last value. Can be nil. If it is nil, `canExecute` is
// always YES.
+ (instancetype)commandWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable execute:(void (^)(id value))executeBlock;

// Creates a new command that can always execute with the given execute block.
+ (instancetype)commandWithExecuteBlock:(void (^)(id value))executeBlock;

// Can the command execute with the given value? If the command was created with
// a canExecute subscribable instead of a block, this will always return YES.
// You should check the `canExecute` propery for the last value sent by the
// subscribable.
//
// value - the value that would be passed into `-execute:` if it returns YES.
//
// Returns whether the command can execute.
- (BOOL)canExecute:(id)value;

// Execute the command with the given value.
//
// value - the value to use in execution.
- (void)execute:(id)value;

// Executes the command with the given value if `-canExecute:` returns YES for
// that value and if the `canExecute` property is YES.
//
// Returns whether the command executed.
//
// value - the vaule to use in execution.
- (BOOL)executeIfAllowed:(id)value;

@end
