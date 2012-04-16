//
//  RACSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"
#import "RACSubscribable+Private.h"
#import "RACSubject.h"
#import "RACDisposable.h"
#import "RACAsyncSubject.h"
#import "NSObject+RACExtensions.h"

static NSMutableSet *activeSubscribables = nil;


@implementation RACSubscribable

+ (void)initialize {
	if(self == [RACSubscribable class]) {
		activeSubscribables = [NSMutableSet set];
	}
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	// we want to keep the subscribable around until all its subscribers are done
	[activeSubscribables addObject:self];
	
	self.subscribers = [NSMutableArray array];
	
	[self invalidateIfNoNewSubscribersShowUp];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	[self.subscribers addObject:subscriber];
	
	__block __unsafe_unretained id weakSelf = self;
	__block __unsafe_unretained id weakSubscriber = subscriber;
	void (^defaultDisposableBlock)(void) = ^{
		RACSubscribable *strongSelf = weakSelf;
		id<RACSubscriber> strongSubscriber = weakSubscriber;
		[strongSelf.subscribers removeObject:strongSubscriber];
		[strongSelf invalidateIfNoNewSubscribersShowUp];
	};
	
	RACDisposable *disposable = nil;
	if(self.didSubscribe != NULL) {
		RACDisposable *innerDisposable = self.didSubscribe(subscriber);
		disposable = [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			defaultDisposableBlock();
		}];
	} else {
		disposable = [RACDisposable disposableWithBlock:defaultDisposableBlock];
	}
	
	[subscriber didSubscribeWithDisposable:disposable];
	
	return disposable;
}


#pragma mark API

@synthesize didSubscribe;
@synthesize subscribers;

+ (id)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSubscribable *subscribable = [[self alloc] init];
	subscribable.didSubscribe = didSubscribe;
	return subscribable;
}

+ (id)return:(id)value {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		[observer sendNext:value];
		[observer sendCompleted];
		return nil;
	}];
}

+ (id)error:(NSError *)error {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		[observer sendError:error];
		return nil;
	}];
}

+ (id)empty {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		[observer sendCompleted];
		return nil;
	}];
}

+ (id)never {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		return nil;
	}];
}

+ (id)start:(id (^)(void))block {
	NSParameterAssert(block != NULL);
	
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		id returned = block();
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if([returned isKindOfClass:[NSError class]]) {
				[subject sendError:returned];
			} else {
				[subject sendNext:returned];
				[subject sendCompleted];
			}
		});
	});
	
	return subject;
}

- (void)invalidateIfNoNewSubscribersShowUp {
	// if no one subscribed in the runloop's pass, then I guess we're free to go
	[self rac_performBlock:^{
		if(self.subscribers.count < 1) {
			[activeSubscribables removeObject:self];
		}
	} afterDelay:0];
}

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block {
	NSParameterAssert(block != NULL);

	for(id<RACSubscriber> subscriber in [self.subscribers copy]) {
		block(subscriber);
	}
}

- (void)tearDown {
	[self.subscribers removeAllObjects];
	[activeSubscribables removeObject:self];
}

@end
