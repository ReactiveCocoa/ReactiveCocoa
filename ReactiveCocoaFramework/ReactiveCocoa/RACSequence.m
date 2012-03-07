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

- (void)unsubscribe:(RACObserver *)observer {
	[self.subscribers removeObject:observer];
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

- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock {
	return [self subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:nextBlock]];
}

- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	return [self subscribe:[RACObserver observerWithCompleted:completedBlock error:NULL next:nextBlock]];
}

- (RACSequence *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	return [self subscribe:[RACObserver observerWithCompleted:completedBlock error:errorBlock next:nextBlock]];
}

- (RACSequence *)subscribeError:(void (^)(NSError *error))errorBlock {
	return [self subscribe:[RACObserver observerWithCompleted:NULL error:errorBlock next:NULL]];
}

- (RACSequence *)subscribeCompleted:(void (^)(void))completedBlock {
	return [self subscribe:[RACObserver observerWithCompleted:completedBlock error:NULL next:NULL]];
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
	} error:^(NSError *error) {
		[filtered sendErrorToAllObservers:error];
	} completed:^{
		[filtered sendCompletedToAllObservers];
	}];
	
	return filtered;
}

- (RACSequence *)select:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACSequence *mapped = [RACSequence sequence];
	[self subscribeNext:^(id x) {
		[mapped addObjectAndNilsAreOK:block(x)];
	} error:^(NSError *error) {
		[mapped sendErrorToAllObservers:error];
	} completed:^{
		[mapped sendCompletedToAllObservers];
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
	} error:^(NSError *error) {
		[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
		[throttled sendErrorToAllObservers:error];
	} completed:^{
		[throttled sendCompletedToAllObservers];
	}];
	
	return throttled;
}

+ (RACSequence *)combineLatest:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock {
	NSParameterAssert(sequences != nil);
	NSParameterAssert(reduceBlock != NULL);
	
	RACSequence *unified = [RACSequence sequence];
	NSMutableSet *completedSequences = [NSMutableSet setWithCapacity:sequences.count];
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			NSMutableArray *latestValues = [NSMutableArray arrayWithCapacity:sequences.count];
			for(RACSequence *sequence in sequences) {
				id lastestValue = [sequence lastObject];
				if(lastestValue != nil) {
					[latestValues addObject:lastestValue];
				} else {
					break;
				}
			}
			
			// It's only a valid event if we have a latest value for all our sequences.
			BOOL valid = latestValues.count == sequences.count;
			if(valid) {
				[unified addObjectAndNilsAreOK:reduceBlock(latestValues)];
			}
		} error:^(NSError *error) {
			[unified sendErrorToAllObservers:error];
			[completedSequences removeAllObjects];
		} completed:^{
			[completedSequences addObject:sequence];
			
			if(completedSequences.count >= sequences.count) {
				[unified sendCompletedToAllObservers];
				[completedSequences removeAllObjects];
			}
		}];
    }
	
	return unified;
}

+ (RACSequence *)merge:(NSArray *)sequences {
	NSParameterAssert(sequences != nil);
	
	RACSequence *unified = [RACSequence sequence];
	NSMutableSet *completedSequences = [NSMutableSet setWithCapacity:sequences.count];
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			[unified addObjectAndNilsAreOK:x];
		} error:^(NSError *error) {
			[unified sendErrorToAllObservers:error];
			[completedSequences removeAllObjects];
		} completed:^{
			[completedSequences addObject:sequence];
			
			if(completedSequences.count >= sequences.count) {
				[unified sendCompletedToAllObservers];
				[completedSequences removeAllObjects];
			}
		}];
    }
	
	return unified;
}

+ (RACSequence *)zip:(NSArray *)sequences reduce:(id (^)(NSArray *xs))reduceBlock {
	NSParameterAssert(sequences != nil);
	NSParameterAssert(reduceBlock != NULL);
	
	RACSequence *unified = [RACSequence sequence];
	NSMutableSet *completedSequences = [NSMutableSet setWithCapacity:sequences.count];
	NSMutableDictionary *currentPairs = [NSMutableDictionary dictionaryWithCapacity:sequences.count];
    for(RACSequence *sequence in sequences) {
		[sequence subscribeNext:^(id x) {
			if(x != nil) {
				[currentPairs setObject:x forKey:[NSString stringWithFormat:@"%p", sequence]];
			}
			
			if(currentPairs.count == sequences.count) {
				[unified addObjectAndNilsAreOK:reduceBlock([currentPairs allValues])];
				[currentPairs removeAllObjects];
			}
		} error:^(NSError *error) {
			[unified sendErrorToAllObservers:error];
			[completedSequences removeAllObjects];
			[currentPairs removeAllObjects];
		} completed:^{
			[completedSequences addObject:sequence];
			
			if(completedSequences.count >= sequences.count) {
				[unified sendCompletedToAllObservers];
				[completedSequences removeAllObjects];
				[currentPairs removeAllObjects];
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
	} error:^(NSError *error) {
		[distinct sendErrorToAllObservers:error];
	} completed:^{
		[distinct sendCompletedToAllObservers];
	}];
	
	return distinct;
}

- (RACSequence *)selectMany:(RACSequence * (^)(id x))selectMany {
	NSParameterAssert(selectMany != NULL);
	
	RACSequence *sequence = [RACSequence sequence];
	NSMutableSet *completedSequences = [NSMutableSet set];
	NSMutableSet *manySequences = [NSMutableSet set];
	
	void (^didComplete)(RACSequence *) = ^(RACSequence *s) {
		[completedSequences addObject:s];
		
		if(completedSequences.count == manySequences.count + 1) {
			[sequence sendCompletedToAllObservers];
			[manySequences removeAllObjects];
			[completedSequences removeAllObjects];
		}
	};
	
	[self subscribeNext:^(id x) {
		RACSequence *many = selectMany(x);
		[manySequences addObject:many];
		[many subscribeNext:^(id x) {
			[sequence addObjectAndNilsAreOK:x];
		} error:^(NSError *error) {
			[sequence sendErrorToAllObservers:error];
		} completed:^{
			didComplete(many);
		}];
	} error:^(NSError *error) {
		[manySequences removeAllObjects];
		[completedSequences removeAllObjects];
		[sequence sendErrorToAllObservers:error];
	} completed:^{
		didComplete(self);
	}];
	
	return sequence;
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
