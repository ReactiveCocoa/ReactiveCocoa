//
//  RACObservable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable.h"
#import "RACObservable+Private.h"
#import "RACSubject.h"

@interface RACObservable ()
@property (nonatomic, strong) NSMutableArray *subscribers;
@end


@implementation RACObservable

- (void)dealloc {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {		
		[self unsubscribe:observer];
	}];
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subscribers = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (id)subscribe:(id<RACObserver>)observer {
	NSParameterAssert(observer != nil);
	
	[self.subscribers addObject:observer];
	
	return observer;
}

- (void)unsubscribe:(id<RACObserver>)observer {
	BOOL isValidSubscriber = [self.subscribers containsObject:observer];
	if(!isValidSubscriber) {
		NSLog(@"WARNING: %@ does not subscribe to %@", observer, self);
		return;
	}
	
	[self.subscribers removeObject:observer];
}


#pragma mark API

@synthesize subscribers;
@synthesize didSubscribe;

+ (id)createObservable:(void (^)(id<RACObserver> observer))didSubscribe {
	RACSubject *subject = [RACSubject subject];
	subject.didSubscribe = didSubscribe;
	return subject;
}

- (void)performBlockOnAllSubscribers:(void (^)(id<RACObserver> observer))block {
	NSParameterAssert(block != NULL);
	
	for(id<RACObserver> observer in [self.subscribers copy]) {
		block(observer);
	}
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert(nextBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:NULL error:NULL next:nextBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:completedBlock error:NULL next:nextBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:completedBlock error:errorBlock next:nextBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:NULL error:errorBlock next:NULL];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:completedBlock error:NULL next:NULL];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithCompleted:NULL error:errorBlock next:nextBlock];
	[self subscribe:o];
	
	return o;
}

@end
