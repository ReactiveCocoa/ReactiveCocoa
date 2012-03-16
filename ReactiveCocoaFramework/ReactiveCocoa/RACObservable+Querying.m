//
//  RACObservable+Querying.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable+Querying.h"
#import "RACObserver.h"
#import "RACSubject.h"
#import "NSObject+GHExtensions.h"

#define RACCreateWeakSelf __block __unsafe_unretained id weakSelf = self;
#define RACRedefineSelf id self = weakSelf;


@implementation RACObservable (Querying)

- (instancetype)select:(id (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		return [self subscribeNext:^(id x) {
			[observer sendNext:selectBlock(x)];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)where:(BOOL (^)(id x))whereBlock {
	NSParameterAssert(whereBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		return [self subscribeNext:^(id x) {
			if(whereBlock(x)) {
				[observer sendNext:x];
			}
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)do:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	[self subscribeNext:block];
	return self;
}

- (instancetype)throttle:(NSTimeInterval)interval {	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			lastDelayedId = [self performBlock:^{
				[observer sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)repeat {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[self subscribe:innerObserver];
		}];
		
		[self subscribe:innerObserver];
		
		return innerObserver;
	}];
}

- (instancetype)defer {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[self subscribe:innerObserver];
		} completed:^{
			[observer sendCompleted];
		}];
		
		[self subscribe:innerObserver];
		
		return innerObserver;
	}];
}

- (instancetype)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	[self subscribeNext:^(id _) {
		
	} error:^(NSError *error) {
		block();
	} completed:^{
		block();
	}];
	
	return self;
}

@end
