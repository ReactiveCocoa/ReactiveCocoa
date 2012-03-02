//
//  RACQueryable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol RACQueryable <NSObject>

- (id<RACQueryable>)where:(BOOL (^)(id value))predicate;
- (id<RACQueryable>)select:(id (^)(id value))block;
- (id<RACQueryable>)throttle:(NSTimeInterval)interval;
- (id<RACQueryable>)selectMany:(id<RACQueryable> (^)(id<RACQueryable> observable))block;
- (id<RACQueryable>)whenAny:(id<RACQueryable>)observable1, ... NS_REQUIRES_NIL_TERMINATION;
- (void)toProperty:(id<RACQueryable>)property;

@end
