//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubject.h"
#import "RACSubscribable+Private.h"
#import "RACDisposable.h"

@interface RACSubject ()
@property (nonatomic, strong) NSMutableArray *subscribers;
@property (nonatomic, strong) NSMutableSet *sources;
@end


@implementation RACSubject

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subscribers = [NSMutableArray array];
	self.sources = [NSMutableSet set];
	
	return self;
}


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)observer {
	RACDisposable *disposable = [super subscribe:observer];
	
	[self.subscribers addObject:[NSValue valueWithNonretainedObject:observer]];
	
	return [RACDisposable disposableWithBlock:^{
		[disposable dispose];
		[self unsubscribeIfActive:observer];
	}];
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self performBlockOnAllSubscribers:^(id<RACSubscriber> observer) {
		[observer sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self removeAllSources];
	
	[self performBlockOnAllSubscribers:^(id<RACSubscriber> observer) {
		[self unsubscribeIfActive:observer];
		[observer sendError:error];
	}];
}

- (void)sendCompleted {
	[self removeAllSources];
	
	[self performBlockOnAllSubscribers:^(id<RACSubscriber> observer) {
		[self unsubscribeIfActive:observer];
		[observer sendCompleted];
	}];
}

- (void)didSubscribeToSubscribable:(id<RACSubscribable>)observable {
	[self.sources addObject:observable];
}

- (void)stopSubscription {
	[self removeAllSources];
}


#pragma mark API

@synthesize subscribers;
@synthesize sources;

+ (id)subject {
	return [[self alloc] init];
}

- (void)performBlockOnAllSubscribers:(void (^)(id<RACSubscriber> observer))block {
	for(NSValue *observer in [self.subscribers copy]) {
		block([observer nonretainedObjectValue]);
	}
}

- (void)unsubscribe:(id<RACSubscriber>)observer {
	NSValue *observerValue = [NSValue valueWithNonretainedObject:observer];
	NSAssert2([self.subscribers containsObject:observerValue], @"%@ does not subscribe to %@", observer, self);
	
	[self.subscribers removeObject:observerValue];
}

- (void)unsubscribeIfActive:(id<RACSubscriber>)observer {
	if([self.subscribers containsObject:[NSValue valueWithNonretainedObject:observer]]) {
		[self unsubscribe:observer];
	}
}

- (void)removeAllSources {
	[self.sources removeAllObjects];
}

@end
