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
#import "RACScheduler.h"

static NSMutableSet *activeSubscribables = nil;

@interface RACSubscribable ()
@property (assign, getter=isTearingDown) BOOL tearingDown;
@end


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
	@synchronized(activeSubscribables) {
		[activeSubscribables addObject:self];
	}
	
	self.subscribers = [NSMutableArray array];
	
	[self invalidateIfNoNewSubscribersShowUp];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	@synchronized(self.subscribers) {
		[self.subscribers addObject:subscriber];
	}
	
	__block __unsafe_unretained id weakSelf = self;
	__block __unsafe_unretained id weakSubscriber = subscriber;
	void (^defaultDisposableBlock)(void) = ^{
		RACSubscribable *strongSelf = weakSelf;
		id<RACSubscriber> strongSubscriber = weakSubscriber;
		// if the disposal is happening because the subscribable's being torn down, we don't need to duplicate the invalidation
		if(!strongSelf.tearingDown) {
			@synchronized(strongSelf.subscribers) {
				[strongSelf.subscribers removeObject:strongSubscriber];
			}
			
			[strongSelf invalidateIfNoNewSubscribersShowUp];
		}
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
@synthesize tearingDown;

+ (id)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSubscribable *subscribable = [[self alloc] init];
	subscribable.didSubscribe = didSubscribe;
	return subscribable;
}

+ (id)return:(id)value {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
		return nil;
	}];
}

+ (id)error:(NSError *)error {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
		return nil;
	}];
}

+ (id)empty {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
		return nil;
	}];
}

+ (id)never {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		return nil;
	}];
}

+ (id)start:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:[RACScheduler backgroundScheduler] block:block];
}

+ (id)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block {
	NSParameterAssert(block != NULL);
	
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	[scheduler schedule:^{
		BOOL success = YES;
		NSError *error = nil;
		id returned = block(&success, &error);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if(!success) {
				[subject sendError:error];
			} else {
				[subject sendNext:returned];
				[subject sendCompleted];
			}
		});
	}];
	
	return subject;
}

- (void)invalidateIfNoNewSubscribersShowUp {
	// if no one subscribed in the runloop's pass, then I guess we're free to go
	[self rac_performBlock:^{
		BOOL noSubscribers = NO;
		@synchronized(self.subscribers) {
			noSubscribers = self.subscribers.count < 1;
		}
		
		if(noSubscribers) {
			@synchronized(activeSubscribables) {
				[activeSubscribables removeObject:self];
			}
		}
	} afterDelay:0];
}

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block {
	NSParameterAssert(block != NULL);

	NSArray *currentSubscribers = nil;
	@synchronized(self.subscribers) {
		currentSubscribers = [self.subscribers copy];
	}
	
	for(id<RACSubscriber> subscriber in currentSubscribers) {
		block(subscriber);
	}
}

- (void)tearDown {
	self.tearingDown = YES;
	
	@synchronized(self.subscribers) {
		[self.subscribers removeAllObjects];
	}
	
	@synchronized(activeSubscribables) {
		[activeSubscribables removeObject:self];
	}
}

@end
