//
//  RACObservableArray.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSequence.h"
#import "RACSequence+Private.h"
#import "RACObserver.h"
#import "NSObject+GHExtensions.h"
#import "RACNil.h"

static const NSUInteger RACObservableSequenceDefaultCapacity = 100;

@interface RACSequence ()

@property (nonatomic, strong) NSMutableArray *backingArray;
@property (nonatomic, strong) NSMutableArray *subscribers;
@property (nonatomic, assign) BOOL suspendNotifications;
@property (nonatomic, assign) NSUInteger capacity;

@end


@implementation RACSequence

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
	return self;
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
	[self.backingArray addObject:object ? : [RACNil nill]];
	
	[self sendNextToAllObservers:object];
	
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

- (id)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	return [self subscribe:[RACObserver observerWithCompleted:completedBlock error:NULL next:nextBlock]];
}

- (id)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock error:(void (^)(NSError *error))errorBlock {
	return [self subscribe:[RACObserver observerWithCompleted:completedBlock error:errorBlock next:nextBlock]];
}

- (void)sendNextToAllObservers:(id)value {
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.next != NULL) {
			observer.next(value);
		}
	}];
}

- (void)sendCompletedToAllObservers {
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.completed != NULL) {
			observer.completed();
		}
	}];
}

- (void)sendErrorToAllObservers:(NSError *)error {
	[self performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.error != NULL) {
			observer.error(error);
		}
	}];
}

- (void)performBlockOnAllObservers:(void (^)(RACObserver *observer))block {
	NSParameterAssert(block != NULL);
	
	if(self.suspendNotifications) return;
	
	for(RACObserver *observer in self.subscribers) {
		block(observer);
	}
}

@end


@implementation RACSequence (QueryableImplementations)


#pragma mark RACQueryable

- (RACSequence *)where:(BOOL (^)(id value))predicate {
	NSParameterAssert(predicate != NULL);
	
	RACSequence *filtered = [RACSequence sequence];
	[self subscribeNext:^(id x) {
		if(predicate(x)) {
			[filtered addObjectAndNilsAreOK:x];
		}
	}];
	
	return filtered;
}

- (RACSequence *)select:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACSequence *mapped = [RACSequence sequence];
	[self subscribeNext:^(id x) {
		id mappedValue = block(x);		
		[mapped addObjectAndNilsAreOK:mappedValue];
	}];
	
	return mapped;
}

- (RACSequence *)throttle:(NSTimeInterval)interval {	
	RACSequence *throttled = [RACSequence sequence];
	__block id lastDelayedId = nil;
	[self subscribeNext:^(id x) {
		[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
		
		BOOL originalSuspendNotifications = throttled.suspendNotifications;
		throttled.suspendNotifications = YES;
		[throttled addObjectAndNilsAreOK:x];
		throttled.suspendNotifications = originalSuspendNotifications;
		
		lastDelayedId = [self performBlock:^{
			[throttled sendNextToAllObservers:[throttled lastObject]];
		} afterDelay:interval];
	}];
	
	return throttled;
}

+ (RACSequence *)combineLatest:(NSArray *)sequences {
	RACSequence *unified = [RACSequence sequence];
	
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			NSMutableArray *topValues = [NSMutableArray arrayWithCapacity:sequences.count];
			for(RACSequence *sequence in sequences) {
				[topValues addObject:[sequence lastObject] ? : [RACNil nill]];
			}
			
			[unified addObjectAndNilsAreOK:topValues];
		}];
    }
	
	return unified;
}

+ (RACSequence *)merge:(NSArray *)sequences {
	RACSequence *unified = [RACSequence sequence];
	
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			[unified addObjectAndNilsAreOK:x];
		}];
    }
	
	return unified;
}

+ (RACSequence *)zip:(NSArray *)sequences {
	RACSequence *unified = [RACSequence sequence];
	
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			NSMutableArray *topValues = [NSMutableArray arrayWithCapacity:sequences.count];
			BOOL valid = YES;
			for(RACSequence *sequence in sequences) {
				id lastValue = [sequence lastObject];
				[topValues addObject:lastValue ? : [RACNil nill]];
				if(lastValue == nil) {
					valid = NO;
					break;
				}
			}
			
			if(valid) {
				[unified addObjectAndNilsAreOK:topValues];
			}
		}];
    }
	
	return unified;
}

- (RACSequence *)toSequence:(RACSequence *)property {
	NSParameterAssert(property != nil);
	
	[self subscribeNext:^(id x) {
		[property addObjectAndNilsAreOK:x];
	}];
	
	return self;
}

- (RACSequence *)toObject:(NSObject *)object keyPath:(NSString *)keyPath {
	NSParameterAssert(keyPath != nil);
	
	[self subscribeNext:^(id x) {
		[object setValue:x forKeyPath:keyPath];
	}];
	
	return self;
}

- (RACSequence *)distinctUntilChanged {
	RACSequence *distinct = [RACSequence sequence];
	[self subscribeNext:^(id x) {
		if(![x isEqual:[distinct lastObject]]) {
			[distinct addObjectAndNilsAreOK:x];
		}
	}];
	
	return distinct;
}

- (RACSequence *)selectMany:(RACSequence * (^)(id x))selectMany {
	RACSequence *other = [RACSequence sequence];
	[self subscribeNext:^(id x) {
		RACSequence *s = selectMany(x);
		[s subscribeNext:^(id x) {
			[other addObject:x];
		}];
	}];
	return other;
}

- (RACSequence *)take:(NSUInteger)count {
	RACSequence *taken = [RACSequence sequence];
	
	__block NSUInteger receivedCount = 0;
	[self subscribeNext:^(id x) {
		receivedCount++;
		
		BOOL notify = receivedCount >= count;
		
		BOOL originalSuspendNotifications = taken.suspendNotifications;
		taken.suspendNotifications = !notify;
		[taken addObjectAndNilsAreOK:x];
		taken.suspendNotifications = originalSuspendNotifications;
		
		if(notify) {
			receivedCount = 0;
		}
	}];
	
	return taken;
}

@end
