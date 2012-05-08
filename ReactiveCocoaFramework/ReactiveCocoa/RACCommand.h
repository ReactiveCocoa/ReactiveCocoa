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

// Whether or not the command can execute.
@property (nonatomic, readonly, assign) BOOL canExecute;

// Creates a new command with no execute or can execute block.
+ (id)command;

// Creates a new command with the given can execute and execute blocks.
//
// canExecuteBlock - the block that is called to determine if the command may
// execute. It is passed the value that would be passed to `-execute:` if it is
// allowed to execute. Can be nil.
//
// executeBlock - the block that will be executed when the command is executed.
// It will be passed the object given to `-execute:`.
+ (id)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock;

+ (id)commandWithCanExecuteObservable:(id<RACSubscribable>)canExecuteObservable execute:(void (^)(id value))executeBlock;

// Can the command execute with the given value?
//
// value - the value that would be passed into `-execute:` if it returns YES.
//
// Returns whether the command can execute.
- (BOOL)canExecute:(id)value;

// Execute the command with the given value.
//
// value - the value to use in execution.
- (void)execute:(id)value;

@end
