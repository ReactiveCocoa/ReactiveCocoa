//
//  NSObject+RACSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACSubscribable.h"
#import "RACSubscriber.h"
#import "RACSubscribable.h"

#define REQUIRES_RAC_SUBSCRIBABLE NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);


@implementation NSObject (RACSubscribable)

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(nextBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:NULL completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	REQUIRES_RAC_SUBSCRIBABLE

	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *))errorBlock completed:(void (^)(void))completedBlock
{
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(completedBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

@end
