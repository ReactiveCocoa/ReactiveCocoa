//
//  NSObject+RACOperations.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;
@class RACTuple;


@interface NSObject (RACOperations)

// Whenever any of given key paths change, it calls `reduceBlock` with a tuple of all the latest values of all the key paths and then sends the returned value of the block as a `next`.
// It also calls `reduceBlock` and sends the returned value as a `next` when the subscribable is first subscribed to.
- (RACSubscribable *)rac_whenAny:(NSArray *)keyPaths reduce:(id (^)(RACTuple *xs))reduceBlock;

@end
