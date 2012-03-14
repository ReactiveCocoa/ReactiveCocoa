//
//  RACQueryable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol RACQueryable <NSObject>

- (id)where:(BOOL (^)(id x))predicate;
- (id)select:(id (^)(id x))block;
- (id)throttle:(NSTimeInterval)interval;
+ (id)combineLatest:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock;
- (id)toSequence:(id)property;
- (id)toObject:(NSObject *)object keyPath:(NSString *)keyPath;
+ (id)merge:(NSArray *)sequences;
- (id)distinctUntilChanged;
+ (id)zip:(NSArray *)queryables reduce:(id (^)(id<RACQueryable>))reduceBlock;
- (id)selectMany:(id<RACQueryable> (^)(id x))selectMany;
- (id)take:(NSUInteger)count;

@end
