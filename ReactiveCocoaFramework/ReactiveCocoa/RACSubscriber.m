//
//  RACSubscriber.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscriber.h"

static NSMutableSet *activeSubscribers = nil;

@interface RACSubscriber ()
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, strong) NSMutableSet *sources;
@end


@implementation RACSubscriber

+ (void)initialize {
	if(self == [RACSubscriber class]) {
		activeSubscribers = [NSMutableSet set];
	}
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.sources = [NSMutableSet set];
	
	return self;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if(self.next != NULL) {
		self.next(value);
	}
}

- (void)sendError:(NSError *)e {
	if(self.error != NULL) {
		self.error(e);
	}
	
	[self removeAllSources];
}

- (void)sendCompleted {
	if(self.completed != NULL) {
		self.completed();
	}
	
	[self removeAllSources];
}

- (void)didSubscribeToSubscribable:(id<RACSubscribable>)observable {
	[self.sources addObject:observable];
	
	[activeSubscribers addObject:self];
}

- (void)stopSubscription {
	[self removeAllSources];
}


#pragma mark API

@synthesize next;
@synthesize error;
@synthesize completed;
@synthesize sources;

+ (id)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *observer = [[self alloc] init];
	observer.next = next;
	observer.error = error;
	observer.completed = completed;
	return observer;
}

- (void)removeAllSources {
	[self.sources removeAllObjects];
	
	[activeSubscribers removeObject:self];
}

@end
