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
- (id<RACQueryable>)whereAny:(id (^)(void))value1Block :(id (^)(void))value2Block :(BOOL (^)(id value1, id value2))block;

@end
