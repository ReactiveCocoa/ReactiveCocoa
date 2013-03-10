//
//  RACSignal+Operations.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal+Operations.h"
#import "EXTScope.h"
#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBehaviorSubject.h"
#import "RACBlockTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACGroupedSignal.h"
#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACSignalSequence.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import "RACMulticastConnection+Private.h"
#import "RACReplaySubject.h"
#import "RACCommand.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

NSString * const RACSignalErrorDomain = @"RACSignalErrorDomain";

const NSInteger RACSignalErrorTimedOut = 1;

// Subscribes to the given signal with the given blocks.
//
// If the signal errors or completes, the corresponding block is invoked. If the
// disposable passed to the block is _not_ disposed, then the signal is
// subscribed to again.
static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *)) {
	next = [next copy];
	error = [error copy];
	completed = [completed copy];

	RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

	RACSchedulerRecursiveBlock recursiveBlock = ^(void (^recurse)(void)) {
		RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
		[compoundDisposable addDisposable:selfDisposable];

		__weak RACDisposable *weakSelfDisposable = selfDisposable;

		RACDisposable *subscriptionDisposable = [signal disposableWithUpdateHandler:next errorHandler:^(NSError *e) {
			@autoreleasepool {
				error(e, compoundDisposable);
				[compoundDisposable removeDisposable:weakSelfDisposable];
			}

			recurse();
		} deallocationHandler:^{
			@autoreleasepool {
				completed(compoundDisposable);
				[compoundDisposable removeDisposable:weakSelfDisposable];
			}

			recurse();
		}];

		if (subscriptionDisposable != nil) [selfDisposable addDisposable:subscriptionDisposable];
	};
	
	// Subscribe once immediately, and then use recursive scheduling for any
	// further resubscriptions.
	recursiveBlock(^{
		RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];

		RACDisposable *schedulingDisposable = [recursiveScheduler disposableWithScheduledRecursiveBlock:recursiveBlock];
		if (schedulingDisposable != nil) [compoundDisposable addDisposable:schedulingDisposable];
	});

	return compoundDisposable;
}

// Used from within -concat to pop the next signal to concatenate to.
static RACDisposable *concatPopNextSignal(NSMutableArray *signals, BOOL *outerDonePtr, id<RACSubscriber> subscriber, RACSignal **currentSignalPtr) {
	NSCParameterAssert(signals != nil);
	NSCParameterAssert(currentSignalPtr != NULL);

	RACSignal *signal;

	@synchronized (signals) {
		if (*outerDonePtr && signals.count == 0 && *currentSignalPtr == nil) {
			[subscriber terminateSubscription];
			return nil;
		}

		if (signals.count == 0 || *currentSignalPtr != nil) return nil;

		signal = signals[0];
		[signals removeObjectAtIndex:0];

		*currentSignalPtr = signal;
	}

	return [signal disposableWithUpdateHandler:^(id x) {
		[subscriber didUpdateWithNewValue:x];
	} errorHandler:^(NSError *error) {
		[subscriber didReceiveErrorWithError:error];
	} deallocationHandler:^{
		@synchronized (signals) {
			*currentSignalPtr = nil;
			concatPopNextSignal(signals, outerDonePtr, subscriber, currentSignalPtr);
		}
	}];
}

@implementation RACSignal (Operations)

- (RACSignal *)doNext:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return [self disposableWithUpdateHandler:^(id x) {
			block(x);
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -doNext:", self.name];
}

- (RACSignal *)doError:(void (^)(NSError *error))block {
	NSParameterAssert(block != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return [self disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			block(error);
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -doError:", self.name];
}

- (RACSignal *)doCompleted:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return [self disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			block();
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -doCompleted:", self.name];
}

- (RACSignal *)throttle:(NSTimeInterval)interval {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		__block RACDisposable *lastDisposable = nil;

		RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
			[lastDisposable dispose];

			dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC));
			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;

			RACDisposable *nextDisposable = [delayScheduler disposableWithDelay:time andBlock:^{
				[subscriber didUpdateWithNewValue:x];
			}];

			@synchronized (scheduler) {
				// This assignment only needs to be synchronized with the
				// disposable returned from -throttle:. The subscriber blocks
				// are already serialized.
				lastDisposable = nextDisposable;
			}
		} errorHandler:^(NSError *error) {
			[lastDisposable dispose];
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[lastDisposable dispose];
			[subscriber terminateSubscription];
		}];

		return [RACDisposable disposableWithBlock:^{
			[subscriptionDisposable dispose];

			@synchronized (scheduler) {
				[lastDisposable dispose];
			}
		}];
	}] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
}

- (RACSignal *)delay:(NSTimeInterval)interval {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
			dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC));
			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;

			RACDisposable *schedulerDisposable = [delayScheduler disposableWithDelay:time andBlock:block];
			if (schedulerDisposable != nil) [disposable addDisposable:schedulerDisposable];
		};

		RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
			schedule(^{
				[subscriber didUpdateWithNewValue:x];
			});
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			schedule(^{
				[subscriber terminateSubscription];
			});
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -delay: %f", self.name, (double)interval];
}

- (RACSignal *)repeat {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return subscribeForever(self,
			^(id x) {
				[subscriber didUpdateWithNewValue:x];
			},
			^(NSError *error, RACDisposable *disposable) {
				[disposable dispose];
				[subscriber didReceiveErrorWithError:error];
			},
			^(RACDisposable *disposable) {
				// Resubscribe.
			});
	}] setNameWithFormat:@"[%@] -repeat", self.name];
}

- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
	NSParameterAssert(catchBlock != NULL);
		
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;

		RACDisposable *outerDisposable = subscribeForever(self,
			^(id x) {
				[subscriber didUpdateWithNewValue:x];
			},
			^(NSError *error, RACDisposable *outerDisposable) {
				[outerDisposable dispose];

				RACSignal *signal = catchBlock(error);
				innerDisposable = [signal subscribe:subscriber];
			},
			^(RACDisposable *outerDisposable) {
				[outerDisposable dispose];
				[subscriber terminateSubscription];
			});

		return [RACDisposable disposableWithBlock:^{
			[outerDisposable dispose];
			[innerDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -catch:", self.name];
}

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
}

- (RACSignal *)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [[[self
		doError:^(NSError *error) {
			block();
		}]
		doCompleted:^{
			block();
		}]
		setNameWithFormat:@"[%@] -finally:", self.name];
}

- (RACSignal *)windowWithStart:(RACSignal *)openSignal close:(RACSignal * (^)(RACSignal *start))closeBlock {
	NSParameterAssert(openSignal != nil);
	NSParameterAssert(closeBlock != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block RACSubject *currentWindow = nil;
		__block RACSignal *currentCloseWindow = nil;
		__block RACDisposable *closeObserverDisposable = NULL;
		
		void (^closeCurrentWindow)(void) = ^{
			[currentWindow terminateSubscription];
			currentWindow = nil;
			currentCloseWindow = nil;
			[closeObserverDisposable dispose], closeObserverDisposable = nil;
		};
		
		RACDisposable *openObserverDisposable = [openSignal subscribe:[RACSubscriber subscriberWithUpdateHandler:^(id x) {
			if(currentWindow == nil) {
				currentWindow = [RACSubject subject];
				[subscriber didUpdateWithNewValue:currentWindow];
				
				currentCloseWindow = closeBlock(currentWindow);
				closeObserverDisposable = [currentCloseWindow subscribe:[RACSubscriber subscriberWithUpdateHandler:^(id x) {
					closeCurrentWindow();
				} errorHandler:^(NSError *error) {
					closeCurrentWindow();
				} completionHandler:^{
					closeCurrentWindow();
				}]];
			}
		} errorHandler:^(NSError *error) {
			
		} completionHandler:^{
			
		}]];
				
		RACDisposable *selfObserverDisposable = [self disposableWithUpdateHandler:^(id x) {
			[currentWindow didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];
				
		return [RACDisposable disposableWithBlock:^{
			[closeObserverDisposable dispose];
			[openObserverDisposable dispose];
			[selfObserverDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -windowWithStart: %@ close:", self.name, openSignal];
}

- (RACSignal *)buffer:(NSUInteger)bufferCount {
	NSParameterAssert(bufferCount > 0);
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:bufferCount];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		RACDisposable *closeDisposable = [windowCloseSubject observerWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:[RACTuple tupleWithObjectsFromArray:values convertNullsToNils:NO]];
			[values removeAllObjects];
		}];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:self close:^(RACSignal *start) {
			return windowCloseSubject;
		}] disposableWithUpdateHandler:^(id x) {		
			innerDisposable = [x observerWithUpdateHandler:^(id x) {
				[values addObject:x ? : [RACTupleNil tupleNil]];
				if(values.count % bufferCount == 0) {
					[windowCloseSubject didUpdateWithNewValue:[RACUnit defaultUnit]];
				}
			}];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
			[closeDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -buffer: %lu", self.name, (unsigned long)bufferCount];
}

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray array];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:self close:^(RACSignal *start) {
			return [[[RACSignal interval:interval] streamWithObjectsUntilIndex:1] doNext:^(id x) {
				[subscriber didUpdateWithNewValue:[RACTuple tupleWithObjectsFromArray:values convertNullsToNils:NO]];
				[values removeAllObjects];
			}];
		}] disposableWithUpdateHandler:^(id x) {
			innerDisposable = [x observerWithUpdateHandler:^(id x) {
				[values addObject:x ? : [RACTupleNil tupleNil]];
			}];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -bufferWithTime: %f", self.name, (double)interval];
}

- (RACSignal *)collect {
	return [[self aggregateWithStartFactory:^{
		return [[NSMutableArray alloc] init];
	} combine:^(NSMutableArray *collectedValues, id x) {
		[collectedValues addObject:(x ?: RACTupleNil.tupleNil)];
		return collectedValues;
	}] setNameWithFormat:@"[%@] -collect", self.name];
}

- (RACSignal *)takeLast:(NSUInteger)count {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {		
		NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];
		return [self disposableWithUpdateHandler:^(id x) {
			[valuesTaken addObject:x ? : [RACTupleNil tupleNil]];
			
			while(valuesTaken.count > count) {
				[valuesTaken removeObjectAtIndex:0];
			}
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			for(id value in valuesTaken) {
				[subscriber didUpdateWithNewValue:[value isKindOfClass:[RACTupleNil class]] ? nil : value];
			}
			
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
}

- (RACSignal *)combineLatestWith:(RACSignal *)signal {
	NSParameterAssert(signal != nil);

	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		__block id lastSelfValue = nil;
		__block BOOL selfCompleted = NO;

		__block id lastOtherValue = nil;
		__block BOOL otherCompleted = NO;

		void (^sendNext)(void) = ^{
			@synchronized (disposable) {
				if (lastSelfValue == nil || lastOtherValue == nil) return;
				[subscriber didUpdateWithNewValue:[RACTuple tupleWithObjects:lastSelfValue, lastOtherValue, nil]];
			}
		};

		RACDisposable *selfDisposable = [self disposableWithUpdateHandler:^(id x) {
			@synchronized (disposable) {
				lastSelfValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			@synchronized (disposable) {
				selfCompleted = YES;
				if (otherCompleted) [subscriber terminateSubscription];
			}
		}];

		if (selfDisposable != nil) [disposable addDisposable:selfDisposable];

		RACDisposable *otherDisposable = [signal disposableWithUpdateHandler:^(id x) {
			@synchronized (disposable) {
				lastOtherValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			@synchronized (disposable) {
				otherCompleted = YES;
				if (selfCompleted) [subscriber terminateSubscription];
			}
		}];

		if (otherDisposable != nil) [disposable addDisposable:otherDisposable];

		return disposable;
	}] setNameWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
	RACSignal *current = nil;

	// The logic here matches that of +[RACStream streamByZippingStreams:]. See that implementation
	// for more information about what's going on here.
	for (RACSignal *signal in signals) {
		if (current == nil) {
			current = [signal streamWithMappedValuesFromBlock:^(id x) {
				return RACTuplePack(x);
			}];

			continue;
		}

		current = [[current combineLatestWith:signal] streamWithMappedValuesFromBlock:^(RACTuple *twoTuple) {
			RACTuple *previousTuple = twoTuple[0];
			return [previousTuple tupleByAddingObject:twoTuple[1]];
		}];
	}

	if (current == nil) return [self empty];
	return [current setNameWithFormat:@"+combineLatest: %@", signals];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock {
	NSParameterAssert(reduceBlock != nil);

	RACSignal *result = [self combineLatest:signals];

	// Although we assert this condition above, older versions of this method
	// supported this argument being nil. Avoid crashing Release builds of
	// apps that depended on that.
	if (reduceBlock != nil) result = [result streamByReducingObjectsWithIterationHandler:reduceBlock];

	return [result setNameWithFormat:@"+combineLatest: %@ reduce:", signals];
}

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
	RACSignal *signal = [RACSignal signalWithSubscriptionHandler:^ RACDisposable * (id<RACSubscriber> subscriber) {
		for (RACSignal *signal in signals) {
			[subscriber didUpdateWithNewValue:signal];
		}
		[subscriber terminateSubscription];
		return nil;
	}].flattened;

	return [signal setNameWithFormat:@"+merge: %@", signals];
}

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSMutableSet *activeSignals = [NSMutableSet setWithObject:self];
		NSMutableSet *disposables = [NSMutableSet set];
		NSMutableArray *queuedSignals = [NSMutableArray array];

		// Returns whether the signal should complete.
		__block BOOL (^dequeueAndSubscribeIfAllowed)(void);
		void (^completeSignal)(RACSignal *) = ^(RACSignal *signal) {
			@synchronized(activeSignals) {
				[activeSignals removeObject:signal];
			}
			
			BOOL completed = dequeueAndSubscribeIfAllowed();
			if (completed) {
				[subscriber terminateSubscription];
			}
		};

		void (^addDisposable)(RACDisposable *) = ^(RACDisposable *disposable) {
			if (disposable == nil) return;
			
			@synchronized(disposables) {
				[disposables addObject:disposable];
			}
		};

		dequeueAndSubscribeIfAllowed = ^{
			RACSignal *signal;
			@synchronized(activeSignals) {
				@synchronized(queuedSignals) {
					BOOL completed = activeSignals.count < 1 && queuedSignals.count < 1;
					if (completed) return YES;

					// We add one to maxConcurrent since self is an active
					// signal at the start and we don't want that to count
					// against the max.
					NSUInteger maxIncludingSelf = maxConcurrent + ([activeSignals containsObject:self] ? 1 : 0);
					if (activeSignals.count >= maxIncludingSelf && maxConcurrent != 0) return NO;

					if (queuedSignals.count < 1) return NO;

					signal = queuedSignals[0];
					[queuedSignals removeObjectAtIndex:0];

					[activeSignals addObject:signal];
				}
			}

			RACDisposable *disposable = [signal subscribe:[RACSubscriber subscriberWithUpdateHandler:^(id x) {
				[subscriber didUpdateWithNewValue:x];
			} errorHandler:^(NSError *error) {
				[subscriber didReceiveErrorWithError:error];
			} completionHandler:^{
				completeSignal(signal);
			}]];

			addDisposable(disposable);

			return NO;
		};

		RACDisposable *disposable = [self disposableWithUpdateHandler:^(id x) {
			NSAssert([x isKindOfClass:RACSignal.class], @"The source must be a signal of signals. Instead, got %@", x);

			RACSignal *innerSignal = x;
			@synchronized(queuedSignals) {
				[queuedSignals addObject:innerSignal];
			}

			dequeueAndSubscribeIfAllowed();
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			completeSignal(self);
		}];

		addDisposable(disposable);

		return [RACDisposable disposableWithBlock:^{
			@synchronized(disposables) {
				[disposables makeObjectsPerformSelector:@selector(dispose)];
			}
			
			dequeueAndSubscribeIfAllowed = nil;
		}];
	}] setNameWithFormat:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
}

- (RACSignal *)sequenceNext:(RACSignal * (^)(void))block {
	NSParameterAssert(block != nil);

	return [[[self materialize] streamByCombiningStreamsFromSignalHandler:^(RACEvent *event) {
		switch (event.eventType) {
			case RACEventTypeCompleted:
				return block();

			case RACEventTypeError:
				return [RACSignal signalWithError:event.error];

			case RACEventTypeNext:
				return [RACSignal empty];

			default:
				NSAssert(NO, @"Unrecognized event type: %i", (int)event.eventType);
		}
	}] setNameWithFormat:@"[%@] -sequenceNext:", self.name];
}

- (RACSignal *)concat {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSMutableArray *signals = [NSMutableArray array];
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		__block BOOL outerDone = NO;
		__block RACSignal *currentSignal = nil;

		RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(RACSignal *signal) {
			NSAssert([signal isKindOfClass:RACSignal.class], @"%@ must be a signal of signals. Instead, got %@", self, signal);

			@synchronized (signals) {
				[signals addObject:signal];

				RACDisposable *nextDisposable = concatPopNextSignal(signals, &outerDone, subscriber, &currentSignal);
				if (nextDisposable != nil) [disposable addDisposable:nextDisposable];
			}
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			@synchronized (signals) {
				outerDone = YES;

				RACDisposable *nextDisposable = concatPopNextSignal(signals, &outerDone, subscriber, &currentSignal);
				if (nextDisposable != nil) [disposable addDisposable:nextDisposable];
			}
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -concat", self.name];
}

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock {
	NSParameterAssert(startFactory != NULL);
	NSParameterAssert(combineBlock != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block id runningValue = startFactory();
		return [self disposableWithUpdateHandler:^(id x) {
			runningValue = combineBlock(runningValue, x);
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber didUpdateWithNewValue:runningValue];
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -aggregateWithStartFactory:combine:", self.name];
}

- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	RACSignal *signal = [self aggregateWithStartFactory:^{
		return start;
	} combine:combineBlock];

	return [signal setNameWithFormat:@"[%@] -aggregateWithStart: %@ combine:", self.name, start];
}

- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object {
	NSParameterAssert(keyPath != nil);
	NSParameterAssert(object != nil);

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	// Purposely not retaining 'object', since we want to tear down the binding
	// when it deallocates normally.
	__block void * volatile objectPtr = (__bridge void *)object;

	RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
		NSObject *object = (__bridge id)objectPtr;
		[object setValue:x forKeyPath:keyPath];
	} errorHandler:^(NSError *error) {
		NSObject *object = (__bridge id)objectPtr;

		NSAssert(NO, @"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);

		[disposable dispose];
	} deallocationHandler:^{
		[disposable dispose];
	}];

	if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];

	#if DEBUG
	static void *bindingsKey = &bindingsKey;
	NSMutableDictionary *bindings;

	@synchronized (object) {
		bindings = objc_getAssociatedObject(object, bindingsKey);
		if (bindings == nil) {
			bindings = [NSMutableDictionary dictionary];
			objc_setAssociatedObject(object, bindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}

	@synchronized (bindings) {
		NSAssert(bindings[keyPath] == nil, @"Signal %@ is already bound to key path \"%@\" on object %@, adding signal %@ is undefined behavior", [bindings[keyPath] nonretainedObjectValue], keyPath, object, self);

		bindings[keyPath] = [NSValue valueWithNonretainedObject:self];
	}
	#endif

	RACDisposable *clearPointerDisposable = [RACDisposable disposableWithBlock:^{
		#if DEBUG
		@synchronized (bindings) {
			[bindings removeObjectForKey:keyPath];
		}
		#endif

		while (YES) {
			void *ptr = objectPtr;
			if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr)) {
				break;
			}
		}
	}];

	[disposable addDisposable:clearPointerDisposable];

	[object rac_addDeallocDisposable:disposable];
	
	RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
	return [RACDisposable disposableWithBlock:^{
		[objectDisposable removeDisposable:disposable];
		[disposable dispose];
	}];
}

+ (RACSignal *)interval:(NSTimeInterval)interval {
	return [[RACSignal interval:interval withLeeway:0.0] setNameWithFormat:@"+interval: %f", (double)interval];
}

+ (RACSignal *)interval:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway {
	NSParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
	NSParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);

	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		int64_t intervalInNanoSecs = (int64_t)(interval * NSEC_PER_SEC);
		int64_t leewayInNanoSecs = (int64_t)(leeway * NSEC_PER_SEC);
		dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, intervalInNanoSecs), (uint64_t)intervalInNanoSecs, (uint64_t)leewayInNanoSecs);
		dispatch_source_set_event_handler(timer, ^{
			[subscriber didUpdateWithNewValue:[NSDate date]];
		});
		dispatch_resume(timer);

		return [RACDisposable disposableWithBlock:^{
			dispatch_source_cancel(timer);
			dispatch_release(timer);
		}];
	}] setNameWithFormat:@"+interval: %f withLeeway: %f", (double)interval, (double)leeway];
}

- (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
		void (^triggerCompletion)(void) = ^{
			[disposable dispose];
			[subscriber terminateSubscription];
		};

		RACDisposable *triggerDisposable = [signalTrigger observerWithUpdateHandler:^(id _) {
			triggerCompletion();
		} completionHandler:^{
			triggerCompletion();
		}];

		if (triggerDisposable != nil) [disposable addDisposable:triggerDisposable];

		RACDisposable *selfDisposable = [self disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[disposable dispose];
			[subscriber terminateSubscription];
		}];

		if (selfDisposable != nil) [disposable addDisposable:selfDisposable];

		return disposable;
	}] setNameWithFormat:@"[%@] -takeUntil: %@", self.name, signalTrigger];
}

- (RACSignal *)switchToLatest {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		__block volatile uint32_t latestChildSignalHasCompleted = 0;
		__block volatile int32_t partialCompletionCount = 0;
		
		RACDisposable *selfDisposable = [self disposableWithUpdateHandler:^(id x) {
			NSAssert([x isKindOfClass:RACSignal.class] || x == nil, @"-switchToLatest requires that the source signal (%@) send signals. Instead we got: %@", self, x);
			
			[innerDisposable dispose], innerDisposable = nil;
			
			int32_t previousChildSignalHadCompleted = OSAtomicAnd32OrigBarrier(0, &latestChildSignalHasCompleted);
			if (previousChildSignalHadCompleted == 1) {
				OSAtomicDecrement32Barrier(&partialCompletionCount);
			}
			
			innerDisposable = [x disposableWithUpdateHandler:^(id x) {
				[subscriber didUpdateWithNewValue:x];
			} errorHandler:^(NSError *error) {
				[subscriber didReceiveErrorWithError:error];
			} deallocationHandler:^{
				OSAtomicOr32Barrier(1, &latestChildSignalHasCompleted);
				
				int32_t currentPartialCompletionCount = OSAtomicIncrement32Barrier(&partialCompletionCount);
				if (currentPartialCompletionCount == 2) {
					[subscriber terminateSubscription];
				}
			}];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			int32_t currentPartialCompletionCount = OSAtomicAdd32Barrier(1, &partialCompletionCount);
			if (currentPartialCompletionCount == 2) {
				[subscriber terminateSubscription];
			}
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[selfDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -switchToLatest", self.name];
}

+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal {
	NSParameterAssert(boolSignal != nil);
	NSParameterAssert(trueSignal != nil);
	NSParameterAssert(falseSignal != nil);

	return [[[boolSignal
		streamWithMappedValuesFromBlock:^(NSNumber *value) {
			NSAssert([value isKindOfClass:NSNumber.class], @"Expected %@ to send BOOLs, not %@", boolSignal, value);
			
			return (value.boolValue ? trueSignal : falseSignal);
		}]
		switchToLatest]
		setNameWithFormat:@"+if: %@ then: %@ else: %@", boolSignal, trueSignal, falseSignal];
}

- (id)first {
	return [self firstOrDefault:nil];
}

- (id)firstOrDefault:(id)defaultValue {
	return [self firstOrDefault:defaultValue success:NULL error:NULL];
}

- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = [NSString stringWithFormat:@"[%@] -firstOrDefault: %@ success:error:", self.name, defaultValue];

	__block id value = defaultValue;
	__block BOOL done = NO;

	// Ensures that we don't pass values across thread boundaries by reference.
	__block NSError *localError;
	__block BOOL localSuccess;

	[[self streamWithObjectsUntilIndex:1] disposableWithUpdateHandler:^(id x) {
		[condition lock];

		value = x;
		localSuccess = YES;
		
		done = YES;
		[condition broadcast];
		[condition unlock];
	} errorHandler:^(NSError *e) {
		[condition lock];

		if (!done) {
			localSuccess = NO;
			localError = e;

			done = YES;
			[condition broadcast];
		}

		[condition unlock];
	} deallocationHandler:^{
		[condition lock];

		localSuccess = YES;

		done = YES;
		[condition broadcast];
		[condition unlock];
	}];

	[condition lock];
	while (!done) {
		[condition wait];
	}

	if (success != NULL) *success = localSuccess;
	if (error != NULL) *error = localError;

	[condition unlock];
	return value;
}

- (BOOL)waitUntilCompleted:(NSError **)error {
	BOOL success = NO;

	[[[self
		ignoreElements]
		setNameWithFormat:@"[%@] -waitUntilCompleted:", self.name]
		firstOrDefault:nil success:&success error:error];
	
	return success;
}

+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return [block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

- (RACSignal *)distinctUntilChanged {
	return [[self bind:^{
		__block id lastValue = nil;
		__block BOOL initial = YES;

		return ^(id x, BOOL *stop) {
			if (!initial && (lastValue == x || [x isEqual:lastValue])) return [RACSignal empty];

			initial = NO;
			lastValue = x;
			return [RACSignal return:x];
		};
	}] setNameWithFormat:@"[%@] -distinctUntilChanged", self.name];
}

- (NSArray *)toArray {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = [NSString stringWithFormat:@"[%@] -toArray", self.name];

	NSMutableArray *values = [NSMutableArray array];
	__block BOOL done = NO;
	[self disposableWithUpdateHandler:^(id x) {
		[values addObject:x ? : [NSNull null]];
	} errorHandler:^(NSError *error) {
		[condition lock];
		done = YES;
		[condition broadcast];
		[condition unlock];
	} deallocationHandler:^{
		[condition lock];
		done = YES;
		[condition broadcast];
		[condition unlock];
	}];

	[condition lock];
	while (!done) {
		[condition wait];
	}

	[condition unlock];

	return [values copy];
}

- (RACSequence *)sequence {
	return [[RACSignalSequence sequenceWithSignal:self] setNameWithFormat:@"[%@] -sequence", self.name];
}

- (RACMulticastConnection *)publish {
	RACSubject *subject = [[RACSubject subject] setNameWithFormat:@"[%@] -publish", self.name];
	RACMulticastConnection *connection = [self multicast:subject];
	return connection;
}

- (RACMulticastConnection *)multicast:(RACSubject *)subject {
	[subject setNameWithFormat:@"[%@] -multicast: %@", self.name, subject.name];
	RACMulticastConnection *connection = [[RACMulticastConnection alloc] initWithSourceSignal:self subject:subject];
	return connection;
}

- (RACSignal *)replay {
	RACReplaySubject *subject = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -replay", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}

- (RACSignal *)replayLast {
	RACReplaySubject *subject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"[%@] -replayLast", self.name];

	RACMulticastConnection *connection = [self multicast:subject];
	[connection connect];

	return connection.signal;
}

- (RACSignal *)replayLazily {
	return [[[self
		multicast:[RACReplaySubject subject]]
		autoconnect]
		setNameWithFormat:@"[%@] -replayLazily", self.name];
}

- (RACSignal *)timeout:(NSTimeInterval)interval {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *timeoutDisposable = [[[RACSignal interval:interval] streamWithObjectsUntilIndex:1] observerWithUpdateHandler:^(id _) {
			[disposable dispose];
			[subscriber didReceiveErrorWithError:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorTimedOut userInfo:nil]];
		}];

		if (timeoutDisposable != nil) [disposable addDisposable:timeoutDisposable];
		
		RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[disposable dispose];
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[disposable dispose];
			[subscriber terminateSubscription];
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -timeout: %f", self.name, (double)interval];
}

- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		void (^schedule)(id) = [^(id block) {
			RACDisposable *schedulingDisposable = [scheduler schedule:block];
			if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
		} copy];

		RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
			schedule(^{
				[subscriber didUpdateWithNewValue:x];
			});
		} errorHandler:^(NSError *error) {
			schedule(^{
				[subscriber didReceiveErrorWithError:error];
			});
		} deallocationHandler:^{
			schedule(^{
				[subscriber terminateSubscription];
			});
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -deliverOn: %@", self.name, scheduler];
}

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *schedulingDisposable = [scheduler schedule:^{
			RACDisposable *subscriptionDisposable = [self disposableWithUpdateHandler:^(id x) {
				[subscriber didUpdateWithNewValue:x];
			} errorHandler:^(NSError *error) {
				[subscriber didReceiveErrorWithError:error];
			} deallocationHandler:^{
				[subscriber terminateSubscription];
			}];

			if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		}];
		
		if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -subscribeOn: %@", self.name, scheduler];
}

- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock {
	NSParameterAssert(letBlock != NULL);
	
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		RACMulticastConnection *connection = [self publish];
		RACDisposable *finalDisposable = [letBlock(connection.signal) disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];
		
		RACDisposable *connectionDisposable = [connection connect];
		
		return [RACDisposable disposableWithBlock:^{
			[connectionDisposable dispose];
			[finalDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -let:", self.name];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
	NSParameterAssert(keyBlock != NULL);

	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSMutableDictionary *groups = [NSMutableDictionary dictionary];

		return [self disposableWithUpdateHandler:^(id x) {
			id<NSCopying> key = keyBlock(x);
			RACGroupedSignal *groupSubject = nil;
			@synchronized(groups) {
				groupSubject = [groups objectForKey:key];
				if(groupSubject == nil) {
					groupSubject = [RACGroupedSignal signalWithKey:key];
					[groups setObject:groupSubject forKey:key];
					[subscriber didUpdateWithNewValue:groupSubject];
				}
			}

			[groupSubject didUpdateWithNewValue:transformBlock != NULL ? transformBlock(x) : x];
		} errorHandler:^(NSError *error) {
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -groupBy:transform:", self.name];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	return [[self groupBy:keyBlock transform:nil] setNameWithFormat:@"[%@] -groupBy:", self.name];
}

- (RACSignal *)any {	
	return [[self any:^(id x) {
		return YES;
	}] setNameWithFormat:@"[%@] -any", self.name];
}

- (RACSignal *)any:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [[[self materialize] bind:^{
		return ^(RACEvent *event, BOOL *stop) {
			if (event.finished) {
				*stop = YES;
				return [RACSignal return:@NO];
			}
			
			if (predicateBlock(event.value)) {
				*stop = YES;
				return [RACSignal return:@YES];
			}

			return [RACSignal empty];
		};
	}] setNameWithFormat:@"[%@] -any:", self.name];
}

- (RACSignal *)all:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [[[self materialize] bind:^{
		return ^(RACEvent *event, BOOL *stop) {
			if (event.eventType == RACEventTypeCompleted) {
				*stop = YES;
				return [RACSignal return:@YES];
			}
			
			if (event.eventType == RACEventTypeError || !predicateBlock(event.value)) {
				*stop = YES;
				return [RACSignal return:@NO];
			}

			return [RACSignal empty];
		};
	}] setNameWithFormat:@"[%@] -all:", self.name];
}

- (RACSignal *)retry:(NSInteger)retryCount {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block NSInteger currentRetryCount = 0;
		return subscribeForever(self,
			^(id x) {
				[subscriber didUpdateWithNewValue:x];
			},
			^(NSError *error, RACDisposable *disposable) {
				if (retryCount == 0 || currentRetryCount < retryCount) {
					// Resubscribe.
					currentRetryCount++;
					return;
				}

				[disposable dispose];
				[subscriber didReceiveErrorWithError:error];
			},
			^(RACDisposable *disposable) {
				[disposable dispose];
				[subscriber terminateSubscription];
			});
	}] setNameWithFormat:@"[%@] -retry: %lu", self.name, (unsigned long)retryCount];
}

- (RACSignal *)retry {
	return [[self retry:0] setNameWithFormat:@"[%@] -retry", self.name];
}

- (RACSignal *)sample:(RACSignal *)sampler {
	NSParameterAssert(sampler != nil);

	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		NSLock *lock = [[NSLock alloc] init];
		__block id lastValue;
		__block BOOL hasValue = NO;

		__block RACDisposable *samplerDisposable;
		RACDisposable *sourceDisposable = [self disposableWithUpdateHandler:^(id x) {
			[lock lock];
			hasValue = YES;
			lastValue = x;
			[lock unlock];
		} errorHandler:^(NSError *error) {
			[samplerDisposable dispose];
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[samplerDisposable dispose];
			[subscriber terminateSubscription];
		}];

		samplerDisposable = [sampler disposableWithUpdateHandler:^(id _) {
			BOOL shouldSend = NO;
			id value;
			[lock lock];
			shouldSend = hasValue;
			value = lastValue;
			[lock unlock];

			if (shouldSend) {
				[subscriber didUpdateWithNewValue:value];
			}
		} errorHandler:^(NSError *error) {
			[sourceDisposable dispose];
			[subscriber didReceiveErrorWithError:error];
		} deallocationHandler:^{
			[sourceDisposable dispose];
			[subscriber terminateSubscription];
		}];

		return [RACDisposable disposableWithBlock:^{
			[samplerDisposable dispose];
			[sourceDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -sample: %@", self.name, sampler];
}

- (RACSignal *)ignoreElements {
	return [[self streamByFilteringInObjectsWithValidationHandler:^(id _) {
		return NO;
	}] setNameWithFormat:@"[%@] -ignoreElements", self.name];
}

- (RACSignal *)materialize {
	return [[RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		return [self disposableWithUpdateHandler:^(id x) {
			[subscriber didUpdateWithNewValue:[RACEvent eventWithValue:x]];
		} errorHandler:^(NSError *error) {
			[subscriber didUpdateWithNewValue:[RACEvent eventWithError:error]];
			[subscriber terminateSubscription];
		} deallocationHandler:^{
			[subscriber didUpdateWithNewValue:RACEvent.completedEvent];
			[subscriber terminateSubscription];
		}];
	}] setNameWithFormat:@"[%@] -materialize", self.name];
}

- (RACSignal *)dematerialize {
	return [[self bind:^{
		return ^(RACEvent *event, BOOL *stop) {
			switch (event.eventType) {
				case RACEventTypeCompleted:
					*stop = YES;
					return [RACSignal empty];

				case RACEventTypeError:
					*stop = YES;
					return [RACSignal signalWithError:event.error];

				case RACEventTypeNext:
					return [RACSignal return:event.value];
			}
		};
	}] setNameWithFormat:@"[%@] -dematerialize", self.name];
}

- (RACSignal *)not {
	return [[self streamWithMappedValuesFromBlock:^(NSNumber *value) {
		NSAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);

		return @(!value.boolValue);
	}] setNameWithFormat:@"[%@] -not", self.name];
}

- (RACDisposable *)executeCommand:(RACCommand *)command {
	NSParameterAssert(command != nil);

	return [self observerWithUpdateHandler:^(id x) {
		[command execute:x];
	}];
}

@end
