//
//  RACQueryable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol RACQueryable <NSObject>

- (id<RACQueryable>)where:(BOOL (^)(id x))predicate;
- (id<RACQueryable>)select:(id (^)(id x))block;
- (id<RACQueryable>)throttle:(NSTimeInterval)interval;
+ (id<RACQueryable>)combineLatest:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock;
- (id<RACQueryable>)toSequence:(id)property;
- (id<RACQueryable>)toObject:(NSObject *)object keyPath:(NSString *)keyPath;
+ (id<RACQueryable>)merge:(NSArray *)sequences;
- (id<RACQueryable>)distinctUntilChanged;
+ (id<RACQueryable>)zip:(NSArray *)queryables reduce:(id (^)(id<RACQueryable>))reduceBlock;
- (id<RACQueryable>)selectMany:(id<RACQueryable> (^)(id x))selectMany;
- (id<RACQueryable>)take:(NSUInteger)count;

@end
