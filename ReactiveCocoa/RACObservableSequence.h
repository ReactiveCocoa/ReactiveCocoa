//
//  RACObservableArray.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACObservable.h"
#import "RACQueryable.h"


@interface RACObservableSequence : NSObject <RACObservable, RACQueryable>

+ (id)sequence;
+ (id)sequenceWithCapacity:(NSUInteger)capacity;

- (void)addObject:(id)object;
- (id)lastObject;

- (RACObservableSequence *)where:(BOOL (^)(id x))predicate;
- (RACObservableSequence *)select:(id (^)(id x))block;
- (RACObservableSequence *)throttle:(NSTimeInterval)interval;
- (RACObservableSequence *)selectMany:(RACObservableSequence * (^)(RACObservableSequence *x))block;
+ (RACObservableSequence *)whenAny:(NSArray *)observables reduce:(id (^)(NSArray *x))reduceBlock;
- (void)toProperty:(RACObservableSequence *)property;

@end
