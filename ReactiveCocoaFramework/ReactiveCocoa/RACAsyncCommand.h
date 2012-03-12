//
//  RACAsyncCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACCommand.h"

@class RACSequence;
@protocol RACAsyncFunctionOperation;


// An async command is a command that can run asynchronous functions when the command is executed.
@interface RACAsyncCommand : RACCommand

// The queue on which the async functions should be performed. By default, this is an NSOperationQueue with a normal priority and a max concurrent operation count of NSOperationQueueDefaultMaxConcurrentOperationCount.
@property (nonatomic, strong) NSOperationQueue *queue;

// The maximum number of concurrent executions allowed. `-canExecute:` will return NO if the number of active executions is greater than or equal to this. `canExecuteValue` is updated as the number of concurrent calls changes.
@property (nonatomic, assign) NSUInteger maxConcurrentExecutions;

@property (readonly, assign) NSUInteger numberOfActiveExecutions;

// Adds a new asynchronous function to the command.
//
// block - the execution block for the async function. The block will be performed in `queue`. The value passed into the block is the value sent to `-execute:`. If an error occurs during the block's execute, it should set `success` to NO and set the error passed into the block. This will cause the sequence's `error` event to be fired. The block's return value will be added to the sequence returned by this method call.
//
// Returns a value to which the command will set the return value of the block.
- (RACValue *)addAsyncFunction:(id (^)(id value, BOOL *success, NSError **error))block;

// Adds a block that will create an operation to be performed when the command is executed.
//
// operationBlock - the block to create an operation when the command is executed.
//
// Returns a value to which the operation will set the value of the operation's execution.
- (RACValue *)addOperationYieldingBlock:(NSOperation<RACAsyncFunctionOperation> * (^)(id value))operationBlock;

@end
