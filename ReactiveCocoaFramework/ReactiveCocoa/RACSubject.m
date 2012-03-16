//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubject.h"
#import "RACObservable+Private.h"
#import "RACDisposable.h"

@interface RACSubject ()
@property (nonatomic, strong) NSMutableArray *subscribers;
@end


@implementation RACSubject

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subscribers = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (RACDisposable *)subscribe:(id<RACObserver>)observer {
	RACDisposable *disposable = [super subscribe:observer];
	
	[self.subscribers addObject:observer];
	
	__block __unsafe_unretained id weakSelf = self;
	return [RACDisposable disposableWithBlock:^{
		RACSubject *strongSelf = weakSelf;
		[disposable dispose];
		[strongSelf unsubscribeIfActive:observer];
	}];
}


#pragma mark RACObserver

- (void)sendNext:(id)value {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendError:error];
		
		[self unsubscribe:observer];
	}];
}

- (void)sendCompleted {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendCompleted];
		
		[self unsubscribe:observer];
	}];
}


#pragma mark API

@synthesize subscribers;

+ (id)subject {
	return [[self alloc] init];
}

- (void)performBlockOnAllSubscribers:(void (^)(id<RACObserver> observer))block {
	for(id<RACObserver> observer in [self.subscribers copy]) {
		block(observer);
	}
}

- (void)unsubscribe:(id<RACObserver>)observer {
	NSAssert2([self.subscribers containsObject:observer], @"%@ does not subscribe to %@", observer, self);
	
	[self.subscribers removeObject:observer];
}

- (void)unsubscribeIfActive:(id<RACObserver>)observer {
	if([self.subscribers containsObject:observer]) {
		[self unsubscribe:observer];
	}
}

@end
