//
//  RACAsyncBlockFunctionOperation.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACAsyncFunctionOperation.h"


@interface RACAsyncBlockFunctionOperation : NSOperation <RACAsyncFunctionOperation>

@property (nonatomic, copy) void (^RACAsyncCallback)(id returnedValue, BOOL success, NSError *error);

+ (id)operationWithCallBlock:(id (^)(BOOL *success, NSError **error))block;

@end
