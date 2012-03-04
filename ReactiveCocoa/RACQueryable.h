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
- (id<RACQueryable>)selectMany:(id<RACQueryable> (^)(id<RACQueryable> x))block;
+ (id<RACQueryable>)combineLatest:(NSArray *)observables reduce:(id (^)(NSArray *x))reduceBlock;
- (void)toProperty:(id<RACQueryable>)property;

@end
