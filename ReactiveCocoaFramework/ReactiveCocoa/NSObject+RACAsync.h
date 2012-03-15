//
//  NSObject+RACAsync.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACObservable;


@interface NSObject (RACAsync)

+ (id<RACObservable>)RACAsync:(id (^)(void))block;

@end
