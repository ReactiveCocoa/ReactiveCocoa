//
//  RACOperation.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableValue.h"

@class RACObservableValue;


@interface RACOperation : NSOperation

+ (id)operationOnQueue:(NSOperationQueue *)queue withBlock:(id (^)(void))block;

- (RACObservableValue *)execute;

@end
