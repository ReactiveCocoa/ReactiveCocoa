//
//  NSObject+RACAsync.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSequence;


@interface NSObject (RACAsync)

+ (RACSequence *)RACAsync:(id (^)(void))block;

@end
