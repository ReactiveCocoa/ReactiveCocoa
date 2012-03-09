//
//  RACAsyncFunction.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSequence;
@protocol RACAsyncFunctionOperation;


@interface RACAsyncFunction : NSObject

+ (id)functionWithOperation:(NSOperation<RACAsyncFunctionOperation> *)operation queue:(NSOperationQueue *)queue;
+ (id)functionWithBlock:(id (^)(BOOL *success, NSError **error))block queue:(NSOperationQueue *)queue;

+ (RACSequence *)executeWithOperation:(NSOperation<RACAsyncFunctionOperation> *)operation queue:(NSOperationQueue *)queue;
+ (RACSequence *)executeWithBlock:(id (^)(BOOL *success, NSError **error))block queue:(NSOperationQueue *)queue;

- (RACSequence *)execute;

@end
