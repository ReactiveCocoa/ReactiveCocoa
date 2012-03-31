//
//  RACSubscribable+Operations.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable.h"


@interface RACSubscribable (Operations)

- (instancetype)select:(id (^)(id x))selectBlock;
- (instancetype)where:(BOOL (^)(id x))whereBlock;
- (instancetype)doNext:(void (^)(id x))block;
- (instancetype)throttle:(NSTimeInterval)interval;
- (instancetype)repeat;
- (instancetype)finally:(void (^)(void))block;
- (instancetype)windowWithStart:(id<RACSubscribable>)openObservable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock;
- (instancetype)buffer:(NSUInteger)bufferCount;
- (instancetype)take:(NSUInteger)count;
+ (instancetype)combineLatest:(NSArray *)observables reduce:(id (^)(NSArray *xs))reduceBlock;
+ (instancetype)whenAll:(NSArray *)observables;
+ (instancetype)merge:(NSArray *)observables;
- (instancetype)selectMany:(id<RACSubscribable> (^)(id x))selectBlock;
- (instancetype)concat:(id<RACSubscribable>)subscribable;
- (instancetype)scanWithStart:(NSInteger)start combine:(NSInteger (^)(NSInteger running, NSInteger next))combineBlock;
- (instancetype)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock;
- (RACDisposable *)toPropery:(NSString *)keyPath onObject:(NSObject *)object;
- (instancetype)startWith:(id)initialValue;
+ (instancetype)interval:(NSTimeInterval)interval;
- (instancetype)takeUntil:(id<RACSubscribable>)subscribableTrigger;
- (instancetype)catchToMaybe;
- (instancetype)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock;
- (instancetype)catchTo:(id<RACSubscribable>)subscribable;
- (id)first;
- (id)firstOrDefault:(id)defaultValue;
- (instancetype)skip:(NSUInteger)skipCount;

// The source must be a subscribable of subscribables.
- (instancetype)switch;

@end
