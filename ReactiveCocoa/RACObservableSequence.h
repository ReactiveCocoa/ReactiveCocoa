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

#define rac_synthesize_seq(a) \
	@synthesize a; \
	- (RACObservableSequence *)a { \
		if(a == nil) { \
			a = [RACObservableSequence sequence]; \
		} \
		return a; \
	}


@interface RACObservableSequence : NSObject <RACObservable, RACQueryable>

+ (id)sequence;
+ (id)sequenceWithCapacity:(NSUInteger)capacity;

- (void)addObject:(id)object;
- (id)lastObject;

- (RACObservableSequence *)where:(BOOL (^)(id x))predicate;
- (RACObservableSequence *)select:(id (^)(id x))block;
- (RACObservableSequence *)throttle:(NSTimeInterval)interval;
- (RACObservableSequence *)selectMany:(RACObservableSequence * (^)(RACObservableSequence *x))block;
+ (RACObservableSequence *)combineLatest:(NSArray *)observables reduce:(id (^)(NSArray *x))reduceBlock;
+ (RACObservableSequence *)merge:(NSArray *)observables;
- (void)toProperty:(RACObservableSequence *)property;
- (RACObservableSequence *)distinctUntilChanged;

- (id)subscribeNext:(void (^)(id x))nextBlock;

@end
