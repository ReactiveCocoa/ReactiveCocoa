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

- (RACObservableSequence *)where:(BOOL (^)(id value))predicate;
- (RACObservableSequence *)select:(id (^)(id value))block;
- (RACObservableSequence *)throttle:(NSTimeInterval)interval;
- (RACObservableSequence *)selectMany:(RACObservableSequence * (^)(RACObservableSequence *observable))block;
+ (RACObservableSequence *)whenAny:(NSArray *)observables reduce:(id (^)(NSArray *observables))reduceBlock;
- (void)toProperty:(RACObservableSequence *)property;

@end
