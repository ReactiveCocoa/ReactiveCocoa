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
#import "RACNil.h"

static const NSUInteger RACObservableSequenceDefaultCapacity = 100;

@interface RACObservableSequence ()

@property (nonatomic, strong) NSMutableArray *backingArray;
@property (nonatomic, strong) NSMutableArray *subscribers;
@property (nonatomic, assign) BOOL suspendNotifications;
@property (nonatomic, assign) NSUInteger capacity;

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
	[self subscribeNext:^(id x) {
		if(predicate(x)) {
			[filtered addObjectAndNilsAreOK:x];
		}
	}];
	
	return filtered;
}

- (RACObservableSequence *)select:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACObservableSequence *mapped = [RACObservableSequence sequence];
	[self subscribeNext:^(id x) {
		id mappedValue = block(x);		
		[mapped addObjectAndNilsAreOK:mappedValue];
	}];
	
	return mapped;
}

- (RACObservableSequence *)throttle:(NSTimeInterval)interval {	
	RACObservableSequence *throttled = [RACObservableSequence sequence];
	__block id lastDelayedId = nil;
	[self subscribeNext:^(id x) {
		[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
		
		throttled.suspendNotifications = YES;
		[throttled addObjectAndNilsAreOK:x];
		throttled.suspendNotifications = NO;
		
		lastDelayedId = [self performBlock:^{
			[throttled performBlockOnAllObservers:^(RACObserver *observer) {
				if(observer.next != NULL) {
					observer.next([throttled lastObject]);
				}
			}];
		} afterDelay:interval];
	}];
	
	return throttled;
}

+ (RACObservableSequence *)combineLatest:(NSArray *)observables {
	RACObservableSequence *unified = [RACObservableSequence sequence];

    for(RACObservableSequence *observable in observables) {
		[observable subscribeNext:^(id x) {
			NSMutableArray *topValues = [NSMutableArray arrayWithCapacity:observables.count];
			for(RACObservableSequence *observable in observables) {
				[topValues addObject:[observable lastObject] ? : [RACNil nill]];
			}
			
			[unified addObjectAndNilsAreOK:topValues];
		}];
    }
	
	return unified;
}

+ (RACObservableSequence *)merge:(NSArray *)observables {
	RACObservableSequence *unified = [RACObservableSequence sequence];
	
    for(RACObservableSequence *observable in observables) {
		[observable subscribeNext:^(id x) {
			[unified addObjectAndNilsAreOK:x];
		}];
    }
	
	return unified;
}

- (void)toProperty:(RACObservableSequence *)property {
	NSParameterAssert(property != nil);
	
	[self subscribeNext:^(id x) {
		[property addObjectAndNilsAreOK:x];
	}];
}

- (RACObservableSequence *)distinctUntilChanged {
	RACObservableSequence *distinct = [RACObservableSequence sequence];
	__block id previousObject = nil;
	[self subscribeNext:^(id x) {
		if(![x isEqual:previousObject]) {
			[distinct addObjectAndNilsAreOK:x];
			previousObject = x;
		}
	}];
	
	return distinct;
}


#pragma mark API

@synthesize backingArray;
@synthesize subscribers;
@synthesize suspendNotifications;
@synthesize capacity;

+ (id)sequence {
	return [self sequenceWithCapacity:RACObservableSequenceDefaultCapacity];
}

+ (id)sequenceWithCapacity:(NSUInteger)capacity {
	return [[self alloc] initWithCapacity:capacity];
}

- (id)initWithCapacity:(NSUInteger)cap {
	self = [self init];
	if(self == nil) return nil;
	
	self.capacity = cap;
	
	return self;
}

- (void)removeFirstObject {
	if(self.count < 1) return;
	
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
	
	while(self.count > self.capacity) {
		[self removeFirstObject];
	}
}

- (NSUInteger)count {
	return self.backingArray.count;
}

- (id)lastObject {
	return [self.backingArray lastObject];
}

- (id)subscribeNext:(void (^)(id x))nextBlock {
	return [self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:nextBlock]];
}

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block {
	NSParameterAssert(block != NULL);
	
	if(self.suspendNotifications) return;
	
	for(RACObserver *observer in self.subscribers) {
		block(observer);
	}
}

@end
