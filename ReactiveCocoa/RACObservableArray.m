//
//  RACObservableArray.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservableArray.h"
#import "RACObservableArray+Private.h"
#import "RACObserver.h"
#import "NSObject+GHExtensions.h"

@interface RACObservableArray ()

@property (nonatomic, strong) NSMutableArray *backingArray;
@property (nonatomic, strong) NSMutableArray *subscribers;
@property (nonatomic, assign) BOOL suspendNotifications;

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block;

@end


@implementation RACObservableArray

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.backingArray = [NSMutableArray array];
	self.subscribers = [NSMutableArray array];
	
	return self;
}


#pragma mark NSArray

- (NSUInteger)count {
	return self.backingArray.count;
}

- (id)objectAtIndex:(NSUInteger)index {
	return [self.backingArray objectAtIndex:index];
}


#pragma mark NSMutableArray

- (id)initWithCapacity:(NSUInteger)numItems {
	self = [self init];
	if(self == nil) return nil;
	
	return self;
}

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index {
	[self.backingArray insertObject:anObject atIndex:index];
	
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.next != NULL) {
			observer.next(anObject);
		}
	}];
}

- (void)removeObjectAtIndex:(NSUInteger)index {
	[self.backingArray removeObjectAtIndex:index];
}

- (void)addObject:(id)anObject {
	[self.backingArray addObject:anObject];
	
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.next != NULL) {
			observer.next(anObject);
		}
	}];
}

- (void)removeLastObject {
	[self.backingArray removeLastObject];
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
	[self.backingArray replaceObjectAtIndex:index withObject:anObject];
}


#pragma mark RACObservable

- (id)subscribe:(RACObserver *)observer {
	[self.subscribers addObject:observer];
	return observer;
}


#pragma mark API

@synthesize backingArray;
@synthesize subscribers;
@synthesize suspendNotifications;

+ (RACObservableArray *)arrayWithArray:(NSArray *)array {
	RACObservableArray *observableArray = [[self alloc] init];
	[observableArray addObjectsFromArray:array];
	
	return observableArray;
}

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block {
	NSParameterAssert(block != NULL);
	
	if(self.suspendNotifications) return;
	
	for(RACObserver *observer in self.subscribers) {
		block(observer);
	}
}

- (RACObservableArray *)where:(BOOL (^)(id value))predicate {
	NSParameterAssert(predicate != NULL);
	
	RACObservableArray *filtered = [RACObservableArray array];
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		if(predicate(value)) {
			[filtered addObjectAndNilsAreOK:value];
		}
	}]];
	
	return filtered;
}

- (RACObservableArray *)select:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACObservableArray *mapped = [RACObservableArray array];
	[self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
		id mappedValue = block(value);		
		[mapped addObjectAndNilsAreOK:mappedValue];
	}]];
	
	return mapped;
}

- (RACObservableArray *)throttle:(NSTimeInterval)interval {	
	RACObservableArray *throttled = [RACObservableArray array];
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

@end
