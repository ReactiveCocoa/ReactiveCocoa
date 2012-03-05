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
+ (id<RACQueryable>)combineLatest:(NSArray *)observables;
- (void)toProperty:(id<RACQueryable>)property;
+ (id<RACQueryable>)combineLatest:(NSArray *)observables;
+ (id<RACQueryable>)merge:(NSArray *)observables;
- (id<RACQueryable>)distinctUntilChanged;
+ (id<RACQueryable>)zip:(NSArray *)observables;
- (id<RACQueryable>)selectMany:(id (^)(id x))selectMany;
- (id<RACQueryable>)take:(NSUInteger)count;

@end
