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
+ (RACObservableSequence *)combineLatest:(NSArray *)observables;
+ (RACObservableSequence *)merge:(NSArray *)observables;
- (void)toProperty:(RACObservableSequence *)property;
- (RACObservableSequence *)distinctUntilChanged;
+ (RACObservableSequence *)zip:(NSArray *)observables;
- (RACObservableSequence *)selectMany:(RACObservableSequence * (^)(id x))selectMany;
- (RACObservableSequence *)take:(NSUInteger)count;

- (id)subscribeNext:(void (^)(id x))nextBlock;
- (id)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

@end
