//
//  RACObserver.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RACObserver : NSObject

@property (nonatomic, readonly, copy) void (^completed)(void);
@property (nonatomic, readonly, copy) void (^error)(NSError *error);
@property (nonatomic, readonly, copy) void (^next)(id x);

// Creates a new observer with the given blocks.
+ (id)observerWithCompleted:(void (^)(void))completed error:(void (^)(NSError *error))error next:(void (^)(id x))next;

@end
