//
//  RACSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable.h"
#import "RACSubscribable+Private.h"
#import "RACSubject.h"
#import "RACDisposable.h"
#import "RACAsyncSubject.h"

static NSMutableSet *activeSubscribables = nil;

@interface RACSubscribable ()

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
	[activeSubscribables addObject:self];
	
	self.subscribers = [NSMutableArray array];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	[self.subscribers addObject:subscriber];
	
	__block __unsafe_unretained id weakSelf = self;
	__block __unsafe_unretained id weakSubscriber = subscriber;
	// the didSubscribe block will usually contain a strong reference to self, so we need to break that retain cycle
	void (^defaultDisposableBlock)(void) = ^{
		RACSubscribable *strongSelf = weakSelf;
		id<RACSubscriber> strongSubscriber = weakSubscriber;
		[strongSelf.subscribers removeObject:strongSubscriber];
		if(strongSelf.subscribers.count < 1) {
			[activeSubscribables removeObject:strongSelf];
			strongSelf.didSubscribe = nil;
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

+ (id)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> observer))didSubscribe {
	RACSubscribable *observable = [[self alloc] init];
	observable.didSubscribe = didSubscribe;
	return observable;
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

@end
