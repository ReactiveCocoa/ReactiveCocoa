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
#import "RACCancelableSignal+Private.h"
#import "RACCompoundDisposable.h"
#import "RACConnectableSignal+Private.h"
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
}

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [self catch:^(NSError *error) {
		return signal;
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
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
	}];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
	return [self combineLatest:signals reduce:nil];
}

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		for (RACSignal *signal in signals) {
			[subscriber sendNext:signal];
		}
		[subscriber sendCompleted];
		return nil;
	}].flatten;
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
	}];
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
	}];
}

- (RACSignal *)concat {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block NSMutableArray *innerSignals = [NSMutableArray array];
		__block RACDisposable *currentDisposable = nil;
		__block BOOL outerDone = NO;
		__block RACSubscriber *innerSubscriber = nil;
		
		void (^startNextInnerSignal)(void) = ^{
			if(innerSignals.count < 1) return;
			
			RACSignal *currentInnerSignal = [innerSignals objectAtIndex:0];
			[innerSignals removeObjectAtIndex:0];
			currentDisposable = [currentInnerSignal subscribe:innerSubscriber];
		};
		
		void (^sendCompletedIfWeReallyAreDone)(void) = ^{
			if(outerDone && innerSignals.count < 1 && currentDisposable == nil) {
				[subscriber sendCompleted];
			}
		};
		
		innerSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			currentDisposable = nil;
			
			startNextInnerSignal();
			sendCompletedIfWeReallyAreDone();
		}];
		
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			NSAssert([x isKindOfClass:RACSignal.class], @"The source must be a signal of signals. Instead, got %@", x);
			[innerSignals addObject:x];
			
			if(currentDisposable == nil) {
				startNextInnerSignal();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			outerDone = YES;
			
			sendCompletedIfWeReallyAreDone();
		}];
		
		return [RACDisposable disposableWithBlock:^{
			innerSignals = nil;
			[sourceDisposable dispose];
			[currentDisposable dispose];
		}];
	}];
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
	}];
}

- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	return [self aggregateWithStartFactory:^{
		return start;
	} combine:combineBlock];
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

		NSAssert(NO, @"Received error in binding for key path \"%@\" on %@: %@", keyPath, object, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in binding for key path \"%@\" on %@: %@", keyPath, object, error);
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
	return [RACSignal interval:interval withLeeway:0.0];
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
	}];
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
	}];
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
	}];
}

- (id)first {
	return [self firstOrDefault:nil];
}

- (id)firstOrDefault:(id)defaultValue {
	return [self firstOrDefault:defaultValue success:NULL error:NULL];
}

- (id)firstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = NSStringFromSelector(_cmd);

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
	}];
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
	}];
}

- (NSArray *)toArray {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = @(__func__);

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
	return [RACSignalSequence sequenceWithSignal:self];
}

- (RACConnectableSignal *)publish {
	return [self multicast:[RACSubject subject]];
}

- (RACConnectableSignal *)multicast:(RACSubject *)subject {
	return [RACConnectableSignal connectableSignalWithSourceSignal:self subject:subject];
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
	}];
}

- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[scheduler schedule:^{
				[subscriber sendNext:x];
			}];
		} error:^(NSError *error) {
			[scheduler schedule:^{
				[subscriber sendError:error];
			}];
		} completed:^{
			[scheduler schedule:^{
				[subscriber sendCompleted];
			}];
		}];
	}];
}

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		[scheduler schedule:^{
			innerDisposable = [self subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
		}];
	}];
}

- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock {
	NSParameterAssert(letBlock != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACConnectableSignal *connectable = [self publish];
		RACDisposable *finalDisposable = [letBlock(connectable) subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		RACDisposable *connectableDisposable = [connectable connect];
		
		return [RACDisposable disposableWithBlock:^{
			[connectableDisposable dispose];
			[finalDisposable dispose];
		}];
	}];
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
	}];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	return [self groupBy:keyBlock transform:nil];
}

- (RACSignal *)any {	
	return [self any:^(id x) {
		return YES;
	}];
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
	}];
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
	}];
}

- (RACSignal *)retry:(NSInteger)retryCount {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block NSInteger currentRetryCount = 0;
		return subscribeForever(self,
			^(id x) {
				[subscriber sendNext:[RACMaybe maybeWithObject:x]];
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
	}];
}

- (RACSignal *)retry {
	return [self retry:0];
}

- (RACCancelableSignal *)asCancelableToSubject:(RACSubject *)subject withBlock:(void (^)(void))block {
	return [RACCancelableSignal cancelableSignalSourceSignal:self subject:subject withBlock:block];
}

- (RACCancelableSignal *)asCancelableWithBlock:(void (^)(void))block {
	return [RACCancelableSignal cancelableSignalSourceSignal:self withBlock:block];
}

- (RACCancelableSignal *)asCancelable {
	return [self asCancelableWithBlock:NULL];
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
	}];
}

@end
