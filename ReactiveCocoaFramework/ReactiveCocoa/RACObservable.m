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
@property (nonatomic, strong) NSMutableArray *disposeBlocks;
@end


@implementation RACObservable

- (void)dealloc {
	for(RACObservableDisposeBlock dispose in self.disposeBlocks) {
		dispose();
	}
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subscribers = [NSMutableArray array];
	self.disposeBlocks = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (RACObservableDisposeBlock)subscribe:(id<RACObserver>)observer {
	NSParameterAssert(observer != nil);
	
	if(self.didSubscribe != NULL) {
		RACObservableDisposeBlock disposeBlock = self.didSubscribe(observer);
		if(disposeBlock != NULL) {
			[self.disposeBlocks addObject:disposeBlock];
		}
	}
	
	[self.subscribers addObject:observer];
	
	__block __unsafe_unretained id weakSelf = self;
	return ^{
		id strongSelf = weakSelf;
		[strongSelf unsubscribe:observer];
	};
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
@synthesize disposeBlocks;

+ (id)createObservable:(id<RACObserver> (^)(id<RACObserver> observer))didSubscribe {
	RACObservable *observable = [[RACObservable alloc] init];
	observable.didSubscribe = didSubscribe;
	return observable;
}

+ (id)return:(id)value {
	return [self createObservable:^(id<RACObserver> observer) {
		[observer sendNext:value];
		[observer sendCompleted];
		return observer;
	}];
}

+ (id)error:(NSError *)error {
	return [self createObservable:^id<RACObserver>(id<RACObserver> observer) {
		[observer sendError:error];
		return observer;
	}];
}

+ (id)complete {
	return [self createObservable:^id<RACObserver>(id<RACObserver> observer) {
		[observer sendCompleted];
		return observer;
	}];
}

+ (id)none {
	return [self createObservable:^id<RACObserver>(id<RACObserver> observer) {
		return observer;
	}];
}

- (void)performBlockOnAllSubscribers:(void (^)(id<RACObserver> observer))block {
	NSParameterAssert(block != NULL);
	
	for(id<RACObserver> observer in [self.subscribers copy]) {
		block(observer);
	}
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert(nextBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:NULL];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:completedBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:completedBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:errorBlock completed:NULL];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:NULL completed:completedBlock];
	[self subscribe:o];
	
	return o;
}

- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:NULL];
	[self subscribe:o];
	
	return o;
}

@end
