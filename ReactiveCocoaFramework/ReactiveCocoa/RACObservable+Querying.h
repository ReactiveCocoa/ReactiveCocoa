//
//  RACObservable+Querying.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable.h"


@interface RACObservable (Querying)

- (instancetype)select:(id (^)(id x))selectBlock;
- (instancetype)where:(BOOL (^)(id x))whereBlock;
- (instancetype)do:(void (^)(id x))block;
- (instancetype)throttle:(NSTimeInterval)interval;
- (instancetype)repeat;
- (instancetype)defer;
- (instancetype)finally:(void (^)(void))block;
- (instancetype)windowWithStart:(id<RACObservable>)openObservable close:(id<RACObservable> (^)(id<RACObservable> start))closeBlock;

@end
