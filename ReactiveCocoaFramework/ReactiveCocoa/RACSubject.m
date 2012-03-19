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


#pragma mark RACObservable

- (RACDisposable *)subscribe:(id<RACObserver>)observer {
	RACDisposable *disposable = [super subscribe:observer];
	
	[self.subscribers addObject:[NSValue valueWithNonretainedObject:observer]];
	
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
	
	[self removeAllSources];
}

- (void)sendCompleted {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendCompleted];
		
		[self unsubscribe:observer];
	}];
	
	[self removeAllSources];
}

- (void)didSubscribeToObservable:(id<RACObservable>)observable {
	[self.sources addObject:observable];
}

- (void)stopObserving {
	[self removeAllSources];
}


#pragma mark API

@synthesize subscribers;
@synthesize sources;

+ (id)subject {
	return [[self alloc] init];
}

- (void)performBlockOnAllSubscribers:(void (^)(id<RACObserver> observer))block {
	for(NSValue *observer in [self.subscribers copy]) {
		block([observer nonretainedObjectValue]);
	}
}

- (void)unsubscribe:(id<RACObserver>)observer {
	NSValue *observerValue = [NSValue valueWithNonretainedObject:observer];
	NSAssert2([self.subscribers containsObject:observerValue], @"%@ does not subscribe to %@", observer, self);
	
	[self.subscribers removeObject:observerValue];
}

- (void)unsubscribeIfActive:(id<RACObserver>)observer {
	if([self.subscribers containsObject:observer]) {
		[self unsubscribe:observer];
	}
}

- (void)removeAllSources {
	[self.sources removeAllObjects];
}

@end
