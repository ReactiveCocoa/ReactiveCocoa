//
//  RACAsyncCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"

@class RACAsyncSubject;


// An async command is a command that can run asynchronous blocks when the
// command is executed.
@interface RACAsyncCommand : RACCommand

// The operation queue on which the async block should be executed. By default,
// this is an operation queue with max concurrent operations set to
// NSOperationQueueDefaultMaxConcurrentOperationCount.
@property (nonatomic, strong) NSOperationQueue *operationQueue;

// The maximum number of concurrent executions allowed.
@property (nonatomic, assign) NSUInteger maxConcurrentExecutions;

// The number of active executions. When this is equal to `maxConcurrentExecutions`,
// `canExecute` will be NO.
@property (readonly, assign) NSUInteger numberOfActiveExecutions;

// Adds a new async block to be called when the command executes.
//
// block - a new block to perform when the command is executed. Cannot be nil.
// The value it is passed is the value given to the command's -execute: call.
- (RACSignal *)addAsyncBlock:(RACSignal * (^)(id value))block;

@end
