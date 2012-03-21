//
//  NSObject+RACSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACSubscribable.h"
#import "RACSubscriber.h"
#import "RACSubscribable.h"


@implementation NSObject (RACSubscribable)

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(nextBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:NULL completed:completedBlock];
	return [(RACSubscribable *) self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert([self conformsToProtocol:@protocol(RACSubscribable)]);
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:NULL];
	return [(RACSubscribable *) self subscribe:o];
}

@end
