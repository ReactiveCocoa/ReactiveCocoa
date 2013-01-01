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
#import "NSObject+RACExtensions.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBehaviorSubject.h"
#import "RACBlockTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACGroupedSignal.h"
#import "RACMaybe.h"
#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACSignalSequence.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import "RACMulticastConnection+Private.h"
#import "RACReplaySubject.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

NSString * const RACSignalErrorDomain = @"RACSignalErrorDomain";

// Subscribes to the given signal with the given blocks.
//
// If the signal errors or completes, the corresponding block is invoked. If the
// disposable passed to the block is _not_ disposed, then the signal is
// subscribed to again.
static RACDisposable *subscribeForever (RACSignal *signal, void (^next)(id), void (^error)(NSError *, RACDisposable *), void (^completed)(RACDisposable *)) {
	next = [next copy];
	error = [error copy];
	completed = [completed copy];

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	RACSchedulerRecursiveBlock recursiveBlock = ^(void (^recurse)(void)) {
		RACDisposable *subscriptionDisposable = [signal subscribeNext:next error:^(NSError *e) {
			error(e, disposable);
			recurse();
		} completed:^{
			completed(disposable);
			recurse();
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
	};
	
	// Subscribe once immediately, and then use recursive scheduling for any
	// further resubscriptions.
	recursiveBlock(^{
		RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];

		RACDisposable *schedulingDisposable = [recursiveScheduler scheduleRecursiveBlock:recursiveBlock];
		if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
	});

	return disposable;
}

@implementation RACSignal (Operations)

- (RACSignal *)doNext:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			block(x);
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -doNext:", self.name];
}

- (RACSignal *)doError:(void (^)(NSError *error))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			block(error);
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -doError:", self.name];
}

- (RACSignal *)doCompleted:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			block();
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -doCompleted:", self.name];
}

- (RACSignal *)throttle:(NSTimeInterval)interval {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			if(lastDelayedId != nil) [self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			lastDelayedId = [self rac_performBlock:^{
				[subscriber sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -throttle: %f", self.name, (double)interval];
}

- (RACSignal *)delay:(NSTimeInterval)interval {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			lastDelayedId = [self rac_performBlock:^{
				[subscriber sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -delay: %f", self.name, (double)interval];
}

- (RACSignal *)repeat {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return subscribeForever(self,
			^(id x) {
				[subscriber sendNext:x];
			},
			^(NSError *error, RACDisposable *disposable) {
				[disposable dispose];
				[subscriber sendError:error];
			},
			^(RACDisposable *disposable) {
				// Resubscribe.
			});
	} name:@"[%@] -repeat", self.name];
}

- (RACSignal *)asMaybes {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return subscribeForever(self,
			^(id x) {
				[subscriber sendNext:[RACMaybe maybeWithObject:x]];
			},
			^(NSError *error, RACDisposable *disposable) {
				[subscriber sendNext:[RACMaybe maybeWithError:error]];
			},
			^(RACDisposable *disposable) {
				[disposable dispose];
				[subscriber sendCompleted];
			});
	} name:@"[%@] -asMaybes", self.name];
}

- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
	NSParameterAssert(catchBlock != NULL);
		
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;

		RACDisposable *outerDisposable = subscribeForever(self,
			^(id x) {
				[subscriber sendNext:x];
			},
			^(NSError *error, RACDisposable *outerDisposable) {
				[outerDisposable dispose];

				RACSignal *signal = catchBlock(error);
				innerDisposable = [signal subscribe:subscriber];
			},
			^(RACDisposable *outerDisposable) {
				[outerDisposable dispose];
				[subscriber sendCompleted];
			});

		return [RACDisposable disposableWithBlock:^{
			[outerDisposable dispose];
			[innerDisposable dispose];
		}];
	} name:@"[%@] -catch:", self.name];
}

- (RACSignal *)catchTo:(RACSignal *)signal {
	RACSignal *result = [self catch:^(NSError *error) {
		return signal;
	}];

	result.name = [NSString stringWithFormat:@"[%@] -catchTo: %@", self.name, signal];
	return result;
}

- (RACSignal *)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
			block();
		} completed:^{
			[subscriber sendCompleted];
			block();
		}];
	} name:@"[%@] -finally:", self.name];
}

- (RACSignal *)windowWithStart:(RACSignal *)openSignal close:(RACSignal * (^)(RACSignal *start))closeBlock {
	NSParameterAssert(openSignal != nil);
	NSParameterAssert(closeBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACSubject *currentWindow = nil;
		__block RACSignal *currentCloseWindow = nil;
		__block RACDisposable *closeObserverDisposable = NULL;
		
		void (^closeCurrentWindow)(void) = ^{
			[currentWindow sendCompleted];
			currentWindow = nil;
			currentCloseWindow = nil;
			[closeObserverDisposable dispose], closeObserverDisposable = nil;
		};
		
		RACDisposable *openObserverDisposable = [openSignal subscribe:[RACSubscriber subscriberWithNext:^(id x) {
			if(currentWindow == nil) {
				currentWindow = [RACSubject subject];
				[subscriber sendNext:currentWindow];
				
				currentCloseWindow = closeBlock(currentWindow);
				closeObserverDisposable = [currentCloseWindow subscribe:[RACSubscriber subscriberWithNext:^(id x) {
					closeCurrentWindow();
				} error:^(NSError *error) {
					closeCurrentWindow();
				} completed:^{
					closeCurrentWindow();
				}]];
			}
		} error:^(NSError *error) {
			
		} completed:^{
			
		}]];
				
		RACDisposable *selfObserverDisposable = [self subscribeNext:^(id x) {
			[currentWindow sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
				
		return [RACDisposable disposableWithBlock:^{
			[closeObserverDisposable dispose];
			[openObserverDisposable dispose];
			[selfObserverDisposable dispose];
		}];
	} name:@"[%@] -windowWithStart: %@ close:", self.name, openSignal];
}

- (RACSignal *)buffer:(NSUInteger)bufferCount {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:bufferCount];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(RACSignal *start) {
			return windowCloseSubject;
		}] subscribeNext:^(id x) {		
			innerDisposable = [x subscribeNext:^(id x) {
				if(values.count % bufferCount == 0) {
					[subscriber sendNext:x];
					[windowCloseSubject sendNext:[RACUnit defaultUnit]];
					[windowOpenSubject sendNext:[RACUnit defaultUnit]];
				}
			}];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	} name:@"[%@] -buffer: %lu", self.name, (unsigned long)bufferCount];
}

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray array];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(RACSignal *start) {
			return [[[RACSignal interval:interval] take:1] doNext:^(id x) {
				[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:values convertNullsToNils:YES]];
				[values removeAllObjects];
				[windowOpenSubject sendNext:[RACUnit defaultUnit]];
			}];
		}] subscribeNext:^(id x) {
			innerDisposable = [x subscribeNext:^(id x) {
				[values addObject:x ? : [RACTupleNil tupleNil]];
			}];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	} name:@"[%@] -bufferWithTime: %f", self.name, (double)interval];
}

- (RACSignal *)collect {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableArray *collectedValues = [[NSMutableArray alloc] init];
		return [self subscribeNext:^(id x) {
			[collectedValues addObject:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:[collectedValues copy]];
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -collect", self.name];
}

- (RACSignal *)takeLast:(NSUInteger)count {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {		
		NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];
		return [self subscribeNext:^(id x) {
			[valuesTaken addObject:x ? : [RACTupleNil tupleNil]];
			
			while(valuesTaken.count > count) {
				[valuesTaken removeObjectAtIndex:0];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			for(id value in valuesTaken) {
				[subscriber sendNext:[value isKindOfClass:[RACTupleNil class]] ? nil : value];
			}
			
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id)reduceBlock {
	NSMutableArray *signalsArray = [NSMutableArray array];
	for (RACSignal *signal in signals) {
		[signalsArray addObject:signal];
	}
	if (signalsArray.count == 0) return self.empty;
	static NSValue *(^keyForSubscriber)(RACSubscriber *) = ^(RACSubscriber *subscriber) {
		return [NSValue valueWithNonretainedObject:subscriber];
	};
	return [RACSignal createSignal:^(id<RACSubscriber> outerSubscriber) {
		NSMutableArray *innerSubscribers = [NSMutableArray arrayWithCapacity:signalsArray.count];
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:signalsArray.count];
		NSMutableSet *completedSignals = [NSMutableSet setWithCapacity:signalsArray.count];
		NSMutableDictionary *lastValues = [NSMutableDictionary dictionaryWithCapacity:signalsArray.count];
		for (RACSignal *signal in signalsArray) {
			__block RACSubscriber *innerSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
				@synchronized(lastValues) {
					lastValues[keyForSubscriber(innerSubscriber)] = x ?: RACTupleNil.tupleNil;
					
					if(lastValues.count == signalsArray.count) {
						NSMutableArray *orderedValues = [NSMutableArray arrayWithCapacity:signalsArray.count];
						for (RACSubscriber *subscriber in innerSubscribers) {
							[orderedValues addObject:lastValues[keyForSubscriber(subscriber)]];
						}
						
						if (reduceBlock == NULL) {
							[outerSubscriber sendNext:[RACTuple tupleWithObjectsFromArray:orderedValues]];
						} else {
							[outerSubscriber sendNext:[RACBlockTrampoline invokeBlock:reduceBlock withArguments:orderedValues]];
						}
					}
				}
			} error:^(NSError *error) {
				[outerSubscriber sendError:error];
			} completed:^{
				@synchronized(completedSignals) {
					[completedSignals addObject:signal];
					if(completedSignals.count == signalsArray.count) {
						[outerSubscriber sendCompleted];
					}
				}
			}];
			[innerSubscribers addObject:innerSubscriber];
			RACDisposable *disposable = [signal subscribe:innerSubscriber];
			
			if (disposable != nil) {
				[disposables addObject:disposable];
			}
		}
		
		return [RACDisposable disposableWithBlock:^{
			for (RACDisposable *disposable in disposables) {
				[disposable dispose];
			}
		}];
	} name:@"+combineLatest: %@ reduce:", signalsArray];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
	RACSignal *signal = [self combineLatest:signals reduce:nil];
	signal.name = [NSString stringWithFormat:@"+combineLatest: %@", signals];
	return signal;
}

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
	RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		for (RACSignal *signal in signals) {
			[subscriber sendNext:signal];
		}
		[subscriber sendCompleted];
		return nil;
	}].flatten;

	signal.name = [NSString stringWithFormat:@"+merge: %@", signals];
	return signal;
}

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
				[subscriber sendCompleted];
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

			RACDisposable *disposable = [signal subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				completeSignal(signal);
			}]];

			addDisposable(disposable);

			return NO;
		};

		RACDisposable *disposable = [self subscribeNext:^(id x) {
			NSAssert([x isKindOfClass:RACSignal.class], @"The source must be a signal of signals. Instead, got %@", x);

			RACSignal *innerSignal = x;
			@synchronized(queuedSignals) {
				[queuedSignals addObject:innerSignal];
			}

			dequeueAndSubscribeIfAllowed();
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			completeSignal(self);
		}];

		addDisposable(disposable);

		return [RACDisposable disposableWithBlock:^{
			@synchronized(disposables) {
				[disposables makeObjectsPerformSelector:@selector(dispose)];
			}
		}];
	} name:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
}

- (RACSignal *)sequenceNext:(RACSignal * (^)(void))block {
	NSParameterAssert(block != nil);

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *nextDisposable = nil;

		RACDisposable *sourceDisposable = [self subscribeError:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			nextDisposable = [block() subscribe:subscriber];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[sourceDisposable dispose];
			[nextDisposable dispose];
		}];
	} name:@"[%@] -sequenceNext:", self.name];
}

- (RACSignal *)concat {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableArray *signals = [NSMutableArray array];
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		__block BOOL outerDone = NO;
		__block RACSignal *currentSignal;

		__block void (^popNextSignal)(void) = [^{
			RACSignal *signal;

			@synchronized (signals) {
				if (outerDone && signals.count == 0 && currentSignal == nil) {
					[subscriber sendCompleted];
					return;
				}

				if (signals.count == 0 || currentSignal != nil) return;

				currentSignal = signals[0];
				[signals removeObjectAtIndex:0];

				signal = currentSignal;
			}

			RACDisposable *innerDisposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@synchronized (signals) {
					currentSignal = nil;
					popNextSignal();
				}
			}];

			if (innerDisposable != nil) [disposable addDisposable:innerDisposable];
		} copy];

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(RACSignal *signal) {
			NSAssert([signal isKindOfClass:RACSignal.class], @"%@ must be a signal of signals. Instead, got %@", self, signal);

			@synchronized (signals) {
				[signals addObject:signal];
				popNextSignal();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (signals) {
				outerDone = YES;
				popNextSignal();
			}
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	} name:@"[%@] -concat", self.name];
}

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock {
	NSParameterAssert(startFactory != NULL);
	NSParameterAssert(combineBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block id runningValue = startFactory();
		return [self subscribeNext:^(id x) {
			runningValue = combineBlock(runningValue, x);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:runningValue];
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -aggregateWithStartFactory:combine:", self.name];
}

- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	RACSignal *signal = [self aggregateWithStartFactory:^{
		return start;
	} combine:combineBlock];

	signal.name = [NSString stringWithFormat:@"[%@] -aggregateWithStart: %@ combine:", self.name, start];
	return signal;
}

- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object {
	NSParameterAssert(keyPath != nil);
	NSParameterAssert(object != nil);

	// Purposely not retaining 'object', since we want to tear down the binding
	// when it deallocates normally.
	__block void * volatile objectPtr = (__bridge void *)object;
	
	RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
		NSObject *object = (__bridge id)objectPtr;
		[object setValue:x forKeyPath:keyPath];
	} error:^(NSError *error) {
		NSObject *object = (__bridge id)objectPtr;

		NSAssert(NO, @"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);
	}];
	
	RACDisposable *disposable = [RACDisposable disposableWithBlock:^{
		while (YES) {
			void *ptr = objectPtr;
			if (OSAtomicCompareAndSwapPtrBarrier(ptr, NULL, &objectPtr)) {
				break;
			}
		}

		[subscriptionDisposable dispose];
	}];

	[object rac_addDeallocDisposable:disposable];

	return disposable;
}

+ (RACSignal *)interval:(NSTimeInterval)interval {
	RACSignal *signal = [RACSignal interval:interval withLeeway:0.0];
	signal.name = [NSString stringWithFormat:@"+interval: %f", (double)interval];
	return signal;
}

+ (RACSignal *)interval:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway {
	NSParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
	NSParameterAssert(leeway >= 0.0 && leeway < INT64_MAX / NSEC_PER_SEC);

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		int64_t intervalInNanoSecs = (int64_t)(interval * NSEC_PER_SEC);
		int64_t leewayInNanoSecs = (int64_t)(leeway * NSEC_PER_SEC);
		dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, intervalInNanoSecs), (uint64_t)intervalInNanoSecs, (uint64_t)leewayInNanoSecs);
		dispatch_source_set_event_handler(timer, ^{
			[subscriber sendNext:[NSDate date]];
		});
		dispatch_resume(timer);

		return [RACDisposable disposableWithBlock:^{
			dispatch_source_cancel(timer);
			dispatch_release(timer);
		}];
	} name:@"+interval: %f withLeeway: %f", (double)interval, (double)leeway];
}

- (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *selfDisposable = nil;
		__block void (^triggerCompletion)() = ^(){
			[selfDisposable dispose], selfDisposable = nil;
			[subscriber sendCompleted];
		};
		__block RACDisposable *triggerDisposable = [signalTrigger subscribeNext:^(id x) {
			triggerCompletion();
		} completed:^{
			triggerCompletion();
		}];
		
		selfDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[triggerDisposable dispose];
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[triggerDisposable dispose];
			[selfDisposable dispose];
		}];
	} name:@"[%@] -takeUntil: %@", self.name, signalTrigger];
}

- (RACSignal *)switch {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			NSAssert([x isKindOfClass:RACSignal.class] || x == nil, @"-switch requires that the source signal (%@) send signals. Instead we got: %@", self, x);
			
			[innerDisposable dispose], innerDisposable = nil;
			
			innerDisposable = [x subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			}];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[selfDisposable dispose];
		}];
	} name:@"[%@] -switch", self.name];
}

+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal {
	NSParameterAssert(boolSignal != nil);
	NSParameterAssert(trueSignal != nil);
	NSParameterAssert(falseSignal != nil);

	RACSignal *signal = [[boolSignal map:^(NSNumber *value) {
		NSAssert([value isKindOfClass:NSNumber.class], @"Expected %@ to send BOOLs, not %@", boolSignal, value);
		
		return (value.boolValue ? trueSignal : falseSignal);
	}] switch];

	signal.name = [NSString stringWithFormat:@"+if: %@ then: %@ else: %@", boolSignal, trueSignal, falseSignal];
	return signal;
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

	// Protects against setting 'value' multiple times (e.g. to the second value
	// instead of the first).
	__block BOOL done = NO;
	__block NSError *localError;

	__block RACDisposable *disposable = [self subscribeNext:^(id x) {
		[condition lock];

		if (!done) {
			value = x;
			if(success != NULL) *success = YES;
			
			done = YES;
			[disposable dispose];
			[condition broadcast];
		}

		[condition unlock];
	} error:^(NSError *e) {
		[condition lock];

		if(success != NULL) *success = NO;
		localError = e;

		done = YES;
		[condition broadcast];
		[condition unlock];
	} completed:^{
		[condition lock];

		if(success != NULL) *success = YES;

		done = YES;
		[condition broadcast];
		[condition unlock];
	}];

	[condition lock];
	while (!done) {
		[condition wait];
	}

	if (error != NULL) *error = localError;

	[condition unlock];
	return value;
}

+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSignal *signal = block();
		return [signal subscribe:[RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	} name:@"+defer:"];
}

- (RACSignal *)distinctUntilChanged {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block id lastValue = nil;
		__block BOOL initial = YES;

		return [self subscribeNext:^(id x) {
			if (initial || (lastValue != x && ![x isEqual:lastValue])) {
				initial = NO;
				lastValue = x;
				[subscriber sendNext:x];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -distinctUntilChanged", self.name];
}

- (NSArray *)toArray {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = [NSString stringWithFormat:@"[%@] -toArray", self.name];

	NSMutableArray *values = [NSMutableArray array];
	__block BOOL done = NO;
	[self subscribeNext:^(id x) {
		[values addObject:x ? : [NSNull null]];
	} error:^(NSError *error) {
		[condition lock];
		done = YES;
		[condition broadcast];
		[condition unlock];
	} completed:^{
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
	RACSequence *sequence = [RACSignalSequence sequenceWithSignal:self];
	sequence.name = [NSString stringWithFormat:@"[%@] -sequence", self.name];
	return sequence;
}

- (RACMulticastConnection *)publish {
	RACSubject *subject = [RACSubject subject];
	RACMulticastConnection *connection = [self multicast:subject];
	subject.name = [NSString stringWithFormat:@"[%@] -publish", self.name];
	return connection;
}

- (RACMulticastConnection *)multicast:(RACSubject *)subject {
	RACMulticastConnection *connection = [RACMulticastConnection connectionWithSourceSignal:self subject:subject];
	connection.signal.name = [NSString stringWithFormat:@"[%@] -multicast: %@", self.name, subject];
	return connection;
}

- (RACSignal *)replay {
	RACMulticastConnection *connection = [self multicast:[RACReplaySubject subject]];
	[connection connect];
	return connection.signal;
}

- (RACSignal *)replayLazily {
	RACMulticastConnection *connection = [self multicast:[RACReplaySubject subject]];
	return [RACSignal defer:^{
		[connection connect];
		return connection.signal;
	}];
}

- (RACSignal *)timeout:(NSTimeInterval)interval {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block volatile uint32_t cancelTimeout = 0;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (interval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			if(cancelTimeout) return;
			
			[subscriber sendError:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorTimedOut userInfo:nil]];
		});
		
		RACDisposable *disposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			OSAtomicOr32Barrier(1, &cancelTimeout);
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			OSAtomicOr32Barrier(1, &cancelTimeout);
			[disposable dispose];
		}];
	} name:@"[%@] -timeout: %f", self.name, (double)interval];
}

- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		void (^schedule)(id) = [^(id block) {
			RACDisposable *schedulingDisposable = [scheduler schedule:block];
			if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
		} copy];

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			schedule(^{
				[subscriber sendNext:x];
			});
		} error:^(NSError *error) {
			schedule(^{
				[subscriber sendError:error];
			});
		} completed:^{
			schedule(^{
				[subscriber sendCompleted];
			});
		}];

		if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		return disposable;
	} name:@"[%@] -deliverOn: %@", self.name, scheduler];
}

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *schedulingDisposable = [scheduler schedule:^{
			RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];

			if (subscriptionDisposable != nil) [disposable addDisposable:subscriptionDisposable];
		}];
		
		if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
		return disposable;
	} name:@"[%@] -subscribeOn: %@", self.name, scheduler];
}

- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock {
	NSParameterAssert(letBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACMulticastConnection *connection = [self publish];
		RACDisposable *finalDisposable = [letBlock(connection.signal) subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		RACDisposable *connectionDisposable = [connection connect];
		
		return [RACDisposable disposableWithBlock:^{
			[connectionDisposable dispose];
			[finalDisposable dispose];
		}];
	} name:@"[%@] -let:", self.name];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
	NSParameterAssert(keyBlock != NULL);

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableDictionary *groups = [NSMutableDictionary dictionary];

		return [self subscribeNext:^(id x) {
			id<NSCopying> key = keyBlock(x);
			RACGroupedSignal *groupSubject = nil;
			@synchronized(groups) {
				groupSubject = [groups objectForKey:key];
				if(groupSubject == nil) {
					groupSubject = [RACGroupedSignal signalWithKey:key];
					[groups setObject:groupSubject forKey:key];
					[subscriber sendNext:groupSubject];
				}
			}

			[groupSubject sendNext:transformBlock != NULL ? transformBlock(x) : x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	} name:@"[%@] -groupBy:transform:", self.name];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	RACSignal *signal = [self groupBy:keyBlock transform:nil];
	signal.name = [NSString stringWithFormat:@"[%@] -groupBy:", self.name];
	return signal;
}

- (RACSignal *)any {	
	RACSignal *signal = [self any:^(id x) {
		return YES;
	}];

	signal.name = [NSString stringWithFormat:@"[%@] -any", self.name];
	return signal;
}

- (RACSignal *)any:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *disposable = [self subscribeNext:^(id x) {
			if(predicateBlock(x)) {
				[subscriber sendNext:@(YES)];
				[disposable dispose];
				[subscriber sendCompleted];
			}
		} error:^(NSError *error) {
			[subscriber sendNext:@(NO)];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:@(NO)];
			[subscriber sendCompleted];
		}];
		
		return disposable;
	} name:@"[%@] -any:", self.name];
}

- (RACSignal *)all:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *disposable = [self subscribeNext:^(id x) {
			if(!predicateBlock(x)) {
				[subscriber sendNext:@(NO)];
				[disposable dispose];
				[subscriber sendCompleted];
			}
		} error:^(NSError *error) {
			[subscriber sendNext:@(NO)];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:@(YES)];
			[subscriber sendCompleted];
		}];
		
		return disposable;
	} name:@"[%@] -all:", self.name];
}

- (RACSignal *)retry:(NSInteger)retryCount {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block NSInteger currentRetryCount = 0;
		return subscribeForever(self,
			^(id x) {
				[subscriber sendNext:x];
			},
			^(NSError *error, RACDisposable *disposable) {
				if (retryCount == 0 || currentRetryCount < retryCount) {
					// Resubscribe.
					currentRetryCount++;
					return;
				}

				[disposable dispose];
				[subscriber sendError:error];
			},
			^(RACDisposable *disposable) {
				[disposable dispose];
				[subscriber sendCompleted];
			});
	} name:@"[%@] -retry: %lu", self.name, (unsigned long)retryCount];
}

- (RACSignal *)retry {
	RACSignal *signal = [self retry:0];
	signal.name = [NSString stringWithFormat:@"[%@] -retry", self.name];
	return signal;
}

- (RACSignal *)sample:(RACSignal *)sampler {
	NSParameterAssert(sampler != nil);

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSLock *lock = [[NSLock alloc] init];
		__block id lastValue;
		__block BOOL hasValue = NO;

		__block RACDisposable *samplerDisposable;
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[lock lock];
			hasValue = YES;
			lastValue = x;
			[lock unlock];
		} error:^(NSError *error) {
			[samplerDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			[samplerDisposable dispose];
			[subscriber sendCompleted];
		}];

		samplerDisposable = [sampler subscribeNext:^(id _) {
			BOOL shouldSend = NO;
			id value;
			[lock lock];
			shouldSend = hasValue;
			value = lastValue;
			[lock unlock];

			if (shouldSend) {
				[subscriber sendNext:value];
			}
		} error:^(NSError *error) {
			[sourceDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			[sourceDisposable dispose];
			[subscriber sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[samplerDisposable dispose];
			[sourceDisposable dispose];
		}];
	} name:@"[%@] -sample: %@", self.name, sampler];
}

@end
