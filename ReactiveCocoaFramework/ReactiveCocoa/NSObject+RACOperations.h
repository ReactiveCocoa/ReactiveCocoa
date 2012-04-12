//
//  NSObject+RACOperations.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;
@class RACTuple;


@interface NSObject (RACOperations)

- (RACSubscribable *)rac_whenAny:(NSArray *)keyPaths reduce:(id (^)(RACTuple *xs))reduceBlock;

@end
