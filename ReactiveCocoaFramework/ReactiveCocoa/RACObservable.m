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
#import "RACDisposable.h"

@interface RACObservable ()
@property (nonatomic, strong) NSMutableArray *disposables;
@end


@implementation RACObservable

- (void)dealloc {
	for(RACDisposable *disposable in self.disposables) {
		[disposable dispose];
	}
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.disposables = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (RACDisposable *)subscribe:(id<RACObserver>)observer {
	NSParameterAssert(observer != nil);
	
	[observer didSubscribeToObservable:self];
	
	if(self.didSubscribe != NULL) {
		__block RACDisposable *disposable = self.didSubscribe(observer);
		if(disposable == nil) {
			__block __unsafe_unretained id weakSelf = self;
			disposable = [RACDisposable disposableWithBlock:^{
				RACObservable *strongSelf = weakSelf;
				[observer stopObserving];
				[strongSelf.disposables removeObject:disposable];
			}];
		}
		
		[self.disposables addObject:disposable];
		return disposable;
	}
	
	return nil;
}


#pragma mark API

@synthesize didSubscribe;
@synthesize disposables;

+ (id)createObservable:(RACDisposable * (^)(id<RACObserver> observer))didSubscribe {
	RACObservable *observable = [[RACObservable alloc] init];
	observable.didSubscribe = didSubscribe;
	return observable;
}

+ (id)return:(id)value {
	return [self createObservable:^RACDisposable *(id<RACObserver> observer) {
		[observer sendNext:value];
		[observer sendCompleted];
		return nil;
	}];
}

+ (id)error:(NSError *)error {
	return [self createObservable:^RACDisposable *(id<RACObserver> observer) {
		[observer sendError:error];
		return nil;
	}];
}

+ (id)empty {
	return [self createObservable:^RACDisposable *(id<RACObserver> observer) {
		[observer sendCompleted];
		return nil;
	}];
}

+ (id)never {
	return [self createObservable:^RACDisposable *(id<RACObserver> observer) {
		return nil;
	}];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert(nextBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:errorBlock completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert(completedBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:NULL error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACObserver *o = [RACObserver observerWithNext:nextBlock error:errorBlock completed:NULL];
	return [self subscribe:o];
}

@end
