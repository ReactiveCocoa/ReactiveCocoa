//
//  RACSequence.h
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
	- (RACSequence *)a { \
		if(a == nil) { \
			a = [RACSequence sequence]; \
		} \
		return a; \
	}

// A sequence is essentially a stream of values.
@interface RACSequence : NSObject <RACObservable, RACQueryable>

+ (id)sequence;
+ (id)sequenceWithCapacity:(NSUInteger)capacity;

- (void)addObject:(id)object;
- (id)lastObject;

// See the documentation for RACQueryable. These are defined here just so that the return type is more specific.
- (RACSequence *)where:(BOOL (^)(id x))predicate;
- (RACSequence *)select:(id (^)(id x))block;
- (RACSequence *)throttle:(NSTimeInterval)interval;
+ (RACSequence *)combineLatest:(NSArray *)observables;
+ (RACSequence *)merge:(NSArray *)observables;
- (void)toProperty:(RACSequence *)property;
- (RACSequence *)distinctUntilChanged;
+ (RACSequence *)zip:(NSArray *)observables;
- (RACSequence *)selectMany:(RACSequence * (^)(id x))selectMany;
- (RACSequence *)take:(NSUInteger)count;

- (id)subscribeNext:(void (^)(id x))nextBlock;
- (id)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;
- (id)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock error:(void (^)(NSError *error))errorBlock;

@end
