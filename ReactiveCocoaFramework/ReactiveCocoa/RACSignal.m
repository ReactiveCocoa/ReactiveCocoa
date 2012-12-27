//
//  RACSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "EXTScope.h"
#import "NSObject+RACExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACBlockTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACScheduler+Private.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import <libkern/OSAtomic.h>

static NSMutableSet *activeSignals() {
	static dispatch_once_t onceToken;
	static NSMutableSet *activeSignal = nil;
	dispatch_once(&onceToken, ^{
		activeSignal = [[NSMutableSet alloc] init];
	});
	
	return activeSignal;
}

@interface RACSignal ()
@property (assign, getter = isTearingDown) BOOL tearingDown;
@end

@implementation RACSignal

#pragma mark Lifecycle

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSignal *signal = [[RACSignal alloc] init];
	signal.didSubscribe = didSubscribe;
	return signal;
}

+ (RACSignal *)error:(NSError *)error {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
		return nil;
	}];
}

+ (RACSignal *)never {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		return nil;
	}];
}

+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:[RACScheduler scheduler] block:block];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:scheduler subjectBlock:^(RACSubject *subject) {
		BOOL success = YES;
		NSError *error = nil;
		id returned = block(&success, &error);
		
		if (!success) {
			[subject sendError:error];
		} else {
			[subject sendNext:returned];
			[subject sendCompleted];
		}
	}];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block {
	NSParameterAssert(block != NULL);

	RACReplaySubject *subject = [RACReplaySubject subject];
	[scheduler schedule:^{
		block(subject);
	}];
	
	return subject;
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	
	// We want to keep the signal around until all its subscribers are done
	@synchronized (activeSignals()) {
		[activeSignals() addObject:self];
	}
	
	self.tearingDown = NO;
	self.subscribers = [NSMutableArray array];
	
	// As soon as we're created we're already trying to be released. Such is life.
	[self invalidateGlobalRefIfNoNewSubscribersShowUp];
	
	return self;
}

- (void)invalidateGlobalRef {
	@synchronized (activeSignals()) {
		[activeSignals() removeObject:self];
	}
}

- (void)invalidateGlobalRefIfNoNewSubscribersShowUp {
	// If no one subscribed in one pass of the main run loop, then we're free to
	// go. It's up to the caller to keep us alive if they still want us.
	[RACScheduler.mainThreadScheduler schedule:^{
		BOOL hasSubscribers = YES;
		@synchronized(self.subscribers) {
			hasSubscribers = self.subscribers.count > 0;
		}

		if (!hasSubscribers) {
			[self invalidateGlobalRef];
		}
	}];
}

- (void)tearDown {
	self.tearingDown = YES;
	
	@synchronized (self.subscribers) {
		[self.subscribers removeAllObjects];
	}
	
	[self invalidateGlobalRef];
}

#pragma mark Managing Subscribers

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block {
	NSParameterAssert(block != NULL);

	NSArray *currentSubscribers = nil;
	@synchronized (self.subscribers) {
		currentSubscribers = [self.subscribers copy];
	}
	
	for (id<RACSubscriber> subscriber in currentSubscribers) {
		block(subscriber);
	}
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> name: %@", self.class, self, self.name];
}

@end

@implementation RACSignal (RACStream)

+ (RACSignal *)empty {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
		return nil;
	}];
}

+ (RACSignal *)return:(id)value {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
		return nil;
	}];
}

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block {
	NSParameterAssert(block != NULL);

	/*
	 * -bind: should:
	 * 
	 * 1. Subscribe to the original signal of values.
	 * 2. Any time the original signal sends a value, transform it using the binding block.
	 * 3. If the binding block returns a signal, subscribe to it, and pass all of its values through to the subscriber as they're received.
	 * 4. If the binding block asks the bind to terminate, complete the _original_ signal.
	 * 5. When _all_ signals complete, send completed to the subscriber.
	 * 
	 * If any signal sends an error at any point, send that to the subscriber.
	 */

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACStreamBindBlock bindingBlock = block();

		NSMutableArray *signals = [NSMutableArray arrayWithObject:self];
		RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

		void (^completeSignal)(RACSignal *) = ^(RACSignal *signal) {
			@synchronized (signals) {
				[signals removeObject:signal];

				if (signals.count == 0) {
					[subscriber sendCompleted];
					[compoundDisposable dispose];
				}
			}
		};

		void (^addSignal)(RACSignal *) = ^(RACSignal *signal) {
			@synchronized (signals) {
				[signals addObject:signal];
			}

			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[compoundDisposable dispose];
				[subscriber sendError:error];
			} completed:^{
				completeSignal(signal);
			}];

			if (disposable != nil) [compoundDisposable addDisposable:disposable];
		};

		RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
			BOOL stop = NO;
			id signal = bindingBlock(x, &stop);

			if (signal != nil) addSignal(signal);
			if (signal == nil || stop) completeSignal(self);
		} error:^(NSError *error) {
			[compoundDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			completeSignal(self);
		}];

		if (bindingDisposable != nil) [compoundDisposable addDisposable:bindingDisposable];

		return compoundDisposable;
	}];
}

- (RACSignal *)map:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:block(x)];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSignal *)concat:(RACSignal *)signal {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *concattedDisposable = nil;
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			concattedDisposable = [signal subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}]];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[sourceDisposable dispose];
			[concattedDisposable dispose];
		}];
	}];
}

- (RACSignal *)flatten {
	return [self flatten:0];
}

+ (RACSignal *)zip:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock {
	NSMutableArray *signalsArray = [NSMutableArray array];
	for (RACSignal *signal in signals) {
		[signalsArray addObject:signal];
	}
	if (signalsArray.count == 0) return self.empty;
	NSUInteger numSignals = signalsArray.count;
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		NSMutableArray *disposables = [NSMutableArray arrayWithCapacity:numSignals];
		NSMutableIndexSet *completedBySignal = [NSMutableIndexSet indexSet];
		NSMutableArray *valuesBySignal = [NSMutableArray arrayWithCapacity:numSignals];
		for (NSUInteger i = 0; i < numSignals; ++i) {
			[valuesBySignal addObject:[NSMutableArray array]];
		}
		
		void (^sendCompleteIfNecessary)(void) = ^{
			for (NSUInteger i = 0; i < numSignals; ++i) {
				if ([valuesBySignal[i] count] == 0) {
					if ([completedBySignal containsIndex:i]) {
						[subscriber sendCompleted];
					}
					return;
				}
			}
		};
		
		for (NSUInteger i = 0; i < numSignals; ++i) {
			RACSignal *signal = signalsArray[i];
			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				@synchronized(valuesBySignal) {
					[valuesBySignal[i] addObject:x ?: RACTupleNil.tupleNil];
					
					BOOL isMissingValues = NO;
					NSMutableArray *earliestValues = [NSMutableArray arrayWithCapacity:numSignals];
					for (NSUInteger j = 0; j < numSignals; ++j) {
						NSArray *nexts = valuesBySignal[j];
						if (nexts.count == 0) {
							isMissingValues = YES;
							break;
						}
						[earliestValues addObject:nexts[0]];
					}
					
					if (!isMissingValues) {
						for (NSMutableArray *nexts in valuesBySignal) {
							[nexts removeObjectAtIndex:0];
						}
						
						if (reduceBlock == NULL) {
							[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:earliestValues]];
						} else {
							[subscriber sendNext:[RACBlockTrampoline invokeBlock:reduceBlock withArguments:earliestValues]];
						}
					}
					
					sendCompleteIfNecessary();
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@synchronized(valuesBySignal) {
					[completedBySignal addIndex:i];
					sendCompleteIfNecessary();
				}
			}];
			
			if (disposable != nil) {
				[disposables addObject:disposable];
			}
		}
		
		return [RACDisposable disposableWithBlock:^{
			[disposables makeObjectsPerformSelector:@selector(dispose)];
		}];
	}];
}

@end

@implementation RACSignal (Subscription)

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	@synchronized (self.subscribers) {
		[self.subscribers addObject:subscriber];
	}
	
	@weakify(self, subscriber);
	RACDisposable *defaultDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self, subscriber);

		// If the disposal is happening because the signal's being torn down, we
		// don't need to duplicate the invalidation.
		if (self.tearingDown) return;

		BOOL stillHasSubscribers = YES;
		@synchronized (self.subscribers) {
			[self.subscribers removeObject:subscriber];
			stillHasSubscribers = self.subscribers.count > 0;
		}
		
		if (!stillHasSubscribers) {
			[self invalidateGlobalRefIfNoNewSubscribersShowUp];
		}
	}];

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ defaultDisposable ]];
	if (self.didSubscribe != NULL) {
		[RACScheduler.subscriptionScheduler schedule:^{
			RACDisposable *innerDisposable = self.didSubscribe(subscriber);
			if (innerDisposable != nil) [disposable addDisposable:innerDisposable];
		}];
	}
	
	[subscriber didSubscribeWithDisposable:disposable];
	
	return disposable;
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	NSParameterAssert(nextBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	NSParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSParameterAssert(nextBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *))errorBlock completed:(void (^)(void))completedBlock {
	NSParameterAssert(completedBlock != NULL);
	NSParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:completedBlock];
	return [self subscribe:o];
}

@end
