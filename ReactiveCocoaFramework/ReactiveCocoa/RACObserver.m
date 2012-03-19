//
//  RACObserver.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObserver.h"

static NSMutableSet *activeObservers = nil;

@interface RACObserver ()
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, strong) NSMutableSet *sources;
@end


@implementation RACObserver

+ (void)initialize {
	if(self == [RACObserver class]) {
		activeObservers = [NSMutableSet set];
	}
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.sources = [NSMutableSet set];
	
	return self;
}


#pragma mark RACObserver

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

- (void)didSubscribeToObservable:(id<RACObservable>)observable {
	[self.sources addObject:observable];
	
	[activeObservers addObject:self];
}

- (void)stopObserving {
	[self removeAllSources];
}


#pragma mark API

@synthesize next;
@synthesize error;
@synthesize completed;
@synthesize sources;

+ (id)observerWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACObserver *observer = [[self alloc] init];
	observer.next = next;
	observer.error = error;
	observer.completed = completed;
	return observer;
}

- (void)removeAllSources {
	[self.sources removeAllObjects];
	
	[activeObservers removeObject:self];
}

@end
