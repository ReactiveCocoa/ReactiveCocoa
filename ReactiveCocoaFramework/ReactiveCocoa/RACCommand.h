//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACValue.h"


// A command is a value that allows more customization of its behavior.
// It sends both `next` and `completed` events when the command executes. `next` is sent the value passed into `-execute:`.
@interface RACCommand : RACValue

// The value that can control whether the command can execute. It is nil by default, but it may be set so that users can use it to control the command's executability.
@property (nonatomic, strong) RACValue *canExecuteValue;

// Creates a new command with no execute or can execute block.
+ (id)command;

// Creates a new command with the given can execute and execute blocks.
//
// canExecuteBlock - the block that is called to determine if the command may execute. It is passed the value that would be passed to `-execute:` if it is allowed to execute. Can be nil.
// executeBlock - the block that will be executed when the command is executed. It will be passed the object given to `-execute:`.
+ (id)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock;

- (BOOL)canExecute:(id)value;
- (void)execute:(id)value;

@end
