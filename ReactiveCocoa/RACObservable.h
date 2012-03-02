//
//  RACObservable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACObserver;


@protocol RACObservable <NSObject>

- (id)subscribe:(RACObserver *)observer;

- (id<RACObservable>)where:(BOOL (^)(id value))predicate;
- (id<RACObservable>)select:(id (^)(id value))block;
- (id<RACObservable>)throttle:(NSTimeInterval)interval;

@end
