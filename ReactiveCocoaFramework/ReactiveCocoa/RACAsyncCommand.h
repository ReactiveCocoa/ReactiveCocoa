//
//  RACAsyncCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACCommand.h"

@class RACAsyncSubject;


// An async command is a command that can run asynchronous functions when the command is executed.
@interface RACAsyncCommand : RACCommand

@property (nonatomic, strong) NSOperationQueue *operationQueue;

// The maximum number of concurrent executions allowed. `-canExecute:` will return NO if the number of active executions is greater than or equal to this. `canExecuteValue` is updated as the number of concurrent calls changes.
@property (nonatomic, assign) NSUInteger maxConcurrentExecutions;

@property (readonly, assign) NSUInteger numberOfActiveExecutions;

- (RACAsyncSubject *)addAsyncFunction:(RACAsyncSubject * (^)(id value))function;

@end
