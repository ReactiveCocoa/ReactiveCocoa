//
//  RACAsyncBlockFunctionOperation.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncBlockFunctionOperation.h"

@interface RACAsyncBlockFunctionOperation ()
@property (nonatomic, copy) id (^callBlock)(BOOL *success, NSError **error);
@end


@implementation RACAsyncBlockFunctionOperation


#pragma mark NSOperation

- (void)main {
	BOOL success = YES;
	NSError *error = nil;
	id value = self.callBlock(&success, &error);
	self.RACAsyncCallback(value, success, error);
}


#pragma mark API

@synthesize RACAsyncCallback;
@synthesize callBlock;

+ (id)operationWithCallBlock:(id (^)(BOOL *success, NSError **error))block {
	RACAsyncBlockFunctionOperation *operation = [[self alloc] init];
	operation.callBlock = block;
	return operation;
}

@end
