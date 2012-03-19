//
//  NSObject+RACObservable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACObservable.h"
#import "RACObserver.h"
#import "RACObservable.h"


@implementation NSObject (RACObservable)

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(nextBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:NULL];
	return [(RACObservable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:completedBlock];
	return [(RACObservable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [(RACObservable *) self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:errorBlock completed:NULL];
	return [(RACObservable *) self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:NULL completed:completedBlock];
	return [(RACObservable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACObservable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:NULL];
	return [(RACObservable *) self subscribe:o];
}

@end
