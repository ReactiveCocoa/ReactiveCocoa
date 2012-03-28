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

@interface RACSubscribable ()
@property (nonatomic, strong) NSMutableArray *disposables;
@end


@implementation RACSubscribable

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


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)observer {
	NSParameterAssert(observer != nil);
	
	[observer didSubscribeToSubscribable:self];
	
	if(self.didSubscribe != NULL) {
		__block RACDisposable *disposable = self.didSubscribe(observer);
		if(disposable == nil) {
			__block __unsafe_unretained id weakSelf = self;
			disposable = [RACDisposable disposableWithBlock:^{
				RACSubscribable *strongSelf = weakSelf;
				[observer stopSubscription];
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

@end
