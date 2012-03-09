//
//  RACAsyncFunction.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncFunction.h"
#import "RACAsyncFunctionOperation.h"
#import "RACSequence.h"
#import "RACSequence+Private.h"
#import "RACAsyncBlockFunctionOperation.h"

@interface RACAsyncFunction ()
@property (nonatomic, strong) NSOperation<RACAsyncFunctionOperation> *operation;
@property (nonatomic, strong) NSOperationQueue *queue;
@end


@implementation RACAsyncFunction


#pragma mark API

@synthesize operation;
@synthesize queue;

+ (id)functionWithOperation:(NSOperation<RACAsyncFunctionOperation> *)operation queue:(NSOperationQueue *)queue {
	RACAsyncFunction *function = [[self alloc] init];
	function.operation = operation;
	function.queue = queue;
	return function;
}

+ (id)functionWithBlock:(id (^)(BOOL *success, NSError **error))block queue:(NSOperationQueue *)queue {
	return [self functionWithOperation:[RACAsyncBlockFunctionOperation operationWithCallBlock:block] queue:queue];
}

+ (RACSequence *)executeWithOperation:(NSOperation<RACAsyncFunctionOperation> *)operation queue:(NSOperationQueue *)queue {
	return [[self functionWithOperation:operation queue:queue] execute];
}

+ (RACSequence *)executeWithBlock:(id (^)(BOOL *success, NSError **error))block queue:(NSOperationQueue *)queue {
	return [[self functionWithBlock:block queue:queue] execute];
}

- (RACSequence *)execute {
	RACSequence *sequence = [RACSequence sequence];
	self.operation.RACAsyncCallback = ^(id returnValue, BOOL success, NSError *error) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			if(success) {
				[sequence addObjectAndNilsAreOK:returnValue];
			} else {
				[sequence sendErrorToAllObservers:error];
			}
		}];
	};
	
	[self.queue addOperation:self.operation];
	
	return sequence;
}

@end
