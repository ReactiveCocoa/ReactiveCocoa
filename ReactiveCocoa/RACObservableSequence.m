//
//  RACObservableArray.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableSequence.h"
#import "RACObservableSequence+Private.h"
#import "RACObserver.h"
#import "NSObject+GHExtensions.h"

@interface RACObservableSequence ()

@property (nonatomic, strong) NSMutableArray *backingArray;
@property (nonatomic, strong) NSMutableArray *subscribers;
@property (nonatomic, assign) BOOL suspendNotifications;

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block;

@end


@implementation RACObservableSequence

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.backingArray = [NSMutableArray array];
	self.subscribers = [NSMutableArray array];
	
	return self;
}


#pragma mark RACObservable

- (id)subscribe:(RACObserver *)observer {
	[self.subscribers addObject:observer];
	return observer;
}


#pragma mark RACQueryable

- (RACObservableSequence *)where:(BOOL (^)(id value))predicate {
	NSParameterAssert(predicate != NULL);
	
	RACObservableSequence *filtered = [RACObservableSequence sequence];
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		if(predicate(value)) {
			[filtered addObjectAndNilsAreOK:value];
		}
	}]];
	
	return filtered;
}

- (RACObservableSequence *)select:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACObservableSequence *mapped = [RACObservableSequence sequence];
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		id mappedValue = block(value);		
		[mapped addObjectAndNilsAreOK:mappedValue];
	}]];
	
	return mapped;
}

- (RACObservableSequence *)throttle:(NSTimeInterval)interval {	
	RACObservableSequence *throttled = [RACObservableSequence sequence];
	__block id lastDelayedId = nil;
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
		
		throttled.suspendNotifications = YES;
		[throttled addObjectAndNilsAreOK:value];
		throttled.suspendNotifications = NO;
		
		lastDelayedId = [self performBlock:^{
			[throttled performBlockOnAllObservers:^(RACObserver *observer) {
				if(observer.next != NULL) {
					observer.next([throttled lastObject]);
				}
			}];
		} afterDelay:interval];
	}]];
	
	return throttled;
}

- (RACObservableSequence *)selectMany:(RACObservableSequence * (^)(RACObservableSequence *observable))block {
	NSParameterAssert(block != NULL);
	
	return block(self);
}

- (RACObservableSequence *)whereAny:(id (^)(void))value1Block :(id (^)(void))value2Block :(BOOL (^)(id value1, id value2))block {
	RACObservableSequence *filtered = [RACObservableSequence sequence];
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		id value1 = value1Block();
		id value2 = value2Block();
		BOOL accept = block(value1, value2);
		if(accept) {
			[filtered addObjectAndNilsAreOK:value];
		}
	}]];
	
	return filtered;
}


#pragma mark API

@synthesize backingArray;
@synthesize subscribers;
@synthesize suspendNotifications;

+ (id)sequence {
	return [[self alloc] init];
}

- (void)removeFirstObject {
	[self.backingArray removeObjectAtIndex:0];
}

- (void)addObject:(id)object {
	NSParameterAssert(object != nil);
	
	[self addObjectAndNilsAreOK:object];
}

- (void)addObjectAndNilsAreOK:(id)object {
	if(object != nil) {
		[self.backingArray addObject:object];
	}
	
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.next != NULL) {
			observer.next(object);
		}
	}];
}

- (NSUInteger)count {
	return self.backingArray.count;
}

- (id)lastObject {
	return [self.backingArray lastObject];
}

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block {
	NSParameterAssert(block != NULL);
	
	if(self.suspendNotifications) return;
	
	for(RACObserver *observer in self.subscribers) {
		block(observer);
	}
}

@end
