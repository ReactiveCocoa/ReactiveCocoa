//
//  RACAsyncFunctionOperation.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol RACAsyncFunctionOperation <NSObject>

// This will set this before the operation's added it a queue. The operation must then call it when it is done. `returnedValue` will get set as the value of the RACVAlue returned by the original `-[RACAsyncCommand addOperation:]` call. If an error occurred, it should pass NO to `success` and send the error.
@property (nonatomic, copy) void (^RACAsyncCallback)(id returnedValue, BOOL success, NSError *error);

@end
