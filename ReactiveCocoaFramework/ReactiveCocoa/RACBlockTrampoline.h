//
//  RACBlockTrampoline.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RACBlockTrampoline : NSObject

+ (id)invokeBlock:(id)block withArguments:(NSArray *)arguments;

@end
