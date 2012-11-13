//
//  RACSubscribableProtocol.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribableProtocol.h"
#import "NSObject+RACExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACCancelableSubscribable+Private.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACDisposable.h"
#import "RACGroupedSubscribable.h"
#import "RACMaybe.h"
#import "RACScheduler.h"
#import "RACSubject.h"
#import "RACSubscribableSequence.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import <libkern/OSAtomic.h>
#import "NSObject+RACPropertySubscribing.h"
#import "RACBlockTrampoline.h"
#import "NSObject+RACFastEnumeration.h"

NSString * const RACSubscribableErrorDomain = @"RACSubscribableErrorDomain";

@concreteprotocol(RACSubscribable)

#pragma mark RACStream

+ (instancetype)empty {
	return nil;
}

+ (instancetype)return:(id)value {
	return nil;
}

// We can't actually provide a useful default implementation of these methods,
// because conforming classes will be required to implement them anyways.
- (instancetype)flattenMap:(id (^)(id value))block {
	return nil;
}

- (instancetype)concat:(id<RACStream>)stream {
	return nil;
}

- (instancetype)flatten {
	return nil;
}

+ (instancetype)zip:(NSArray *)streams reduce:(id)reduceBlock {
	return nil;
}

#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return nil;
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

- (id<RACSubscribable>)mapReplace:(id)object {
	return [self map:^(id _) {
		return object;
	}];
}

- (id<RACSubscribable>)injectObjectWeakly:(id)object {
	__unsafe_unretained id weakObject = object;
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			id strongObject = weakObject;
			[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:[NSArray arrayWithObjects:x ? : [RACTupleNil tupleNil], strongObject, nil]]];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (id<RACSubscribable>)doNext:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)doError:(void (^)(NSError *error))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)doCompleted:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)throttle:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)delay:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)repeat {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *currentDisposable = nil;
		
		__block RACSubscriber *innerObserver = [RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			currentDisposable = [self subscribe:innerObserver];
		}];
		
		currentDisposable = [self subscribe:innerObserver];
		
		return [RACDisposable disposableWithBlock:^{
			[currentDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)asMaybes {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *currentDisposable = nil;
		
		__block RACSubscriber *innerObserver = [RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:[RACMaybe maybeWithObject:x]];
		} error:^(NSError *error) {
			[subscriber sendNext:[RACMaybe maybeWithError:error]];
			currentDisposable = [self subscribe:innerObserver];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		currentDisposable = [self subscribe:innerObserver];
		
		return [RACDisposable disposableWithBlock:^{
			[currentDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock {
	NSParameterAssert(catchBlock != NULL);
		
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			id<RACSubscribable> subscribable = catchBlock(error);
			innerDisposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}]];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)catchTo:(id<RACSubscribable>)subscribable {
	return [self catch:^(NSError *error) {
		return subscribable;
	}];
}

- (id<RACSubscribable>)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock {
	NSParameterAssert(openSubscribable != nil);
	NSParameterAssert(closeBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACSubject *currentWindow = nil;
		__block id<RACSubscribable> currentCloseWindow = nil;
		__block RACDisposable *closeObserverDisposable = NULL;
		
		void (^closeCurrentWindow)(void) = ^{
			[currentWindow sendCompleted];
			currentWindow = nil;
			currentCloseWindow = nil;
			[closeObserverDisposable dispose], closeObserverDisposable = nil;
		};
		
		RACDisposable *openObserverDisposable = [openSubscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
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

- (id<RACSubscribable>)buffer:(NSUInteger)bufferCount {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:bufferCount];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(id<RACSubscribable> start) {
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

- (id<RACSubscribable>)bufferWithTime:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray array];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(id<RACSubscribable> start) {
			return [[[RACSubscribable interval:interval] take:1] doNext:^(id x) {
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

- (id<RACSubscribable>)takeLast:(NSUInteger)count {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {		
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

+ (id<RACSubscribable>)combineLatest:(NSArray *)subscribables reduce:(id)reduceBlock {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:subscribables.count];
		NSMutableSet *completedSubscribables = [NSMutableSet setWithCapacity:subscribables.count];
		NSMutableDictionary *lastValues = [NSMutableDictionary dictionaryWithCapacity:subscribables.count];
		for(id<RACSubscribable> subscribable in subscribables) {
			RACDisposable *disposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				@synchronized(lastValues) {
					[lastValues setObject:x ? : [RACTupleNil tupleNil] forKey:[NSString stringWithFormat:@"%p", subscribable]];

					if(lastValues.count == subscribables.count) {
						NSMutableArray *orderedValues = [NSMutableArray arrayWithCapacity:subscribables.count];
						for(id<RACSubscribable> o in subscribables) {
							[orderedValues addObject:[lastValues objectForKey:[NSString stringWithFormat:@"%p", o]]];
						}

						if (reduceBlock == NULL) {
							[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:orderedValues]];
						} else {
							[subscriber sendNext:[RACBlockTrampoline invokeBlock:reduceBlock withArguments:orderedValues]];
						}
					}
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@synchronized(completedSubscribables) {
					[completedSubscribables addObject:subscribable];
					if(completedSubscribables.count == subscribables.count) {
						[subscriber sendCompleted];
					}
				}
			}]];

			if(disposable != nil) {
				[disposables addObject:disposable];
			}
		}

		return [RACDisposable disposableWithBlock:^{
			for(RACDisposable *disposable in disposables) {
				[disposable dispose];
			}
		}];
	}];
}

+ (id<RACSubscribable>)combineLatest:(NSArray *)subscribables {
	return [self combineLatest:subscribables reduce:nil];
}

+ (id<RACSubscribable>)merge:(NSArray *)subscribables {
	return [subscribables.rac_toSubscribable flatten];
}

- (id<RACSubscribable>)flatten:(NSUInteger)maxConcurrent {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableSet *activeSubscribables = [NSMutableSet setWithObject:self];
		NSMutableSet *disposables = [NSMutableSet set];
		NSMutableArray *queuedSubscribables = [NSMutableArray array];

		// Returns whether the subscribable should complete.
		__block BOOL (^dequeueAndSubscribeIfAllowed)(void);
		void (^completeSubscribable)(id<RACSubscribable>) = ^(id<RACSubscribable> subscribable) {
			@synchronized(activeSubscribables) {
				[activeSubscribables removeObject:subscribable];
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
			id<RACSubscribable> subscribable;
			@synchronized(activeSubscribables) {
				@synchronized(queuedSubscribables) {
					BOOL completed = activeSubscribables.count < 1 && queuedSubscribables.count < 1;
					if (completed) return YES;

					// We add one to maxConcurrent since self is an active
					// subscribable at the start and we don't want that to count
					// against the max.
					NSUInteger maxIncludingSelf = maxConcurrent + ([activeSubscribables containsObject:self] ? 1 : 0);
					if (activeSubscribables.count >= maxIncludingSelf && maxConcurrent != 0) return NO;

					if (queuedSubscribables.count < 1) return NO;

					subscribable = queuedSubscribables[0];
					[queuedSubscribables removeObjectAtIndex:0];

					[activeSubscribables addObject:subscribable];
				}
			}

			RACDisposable *disposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				completeSubscribable(subscribable);
			}]];

			addDisposable(disposable);

			return NO;
		};

		RACDisposable *disposable = [self subscribeNext:^(id x) {
			NSAssert([x conformsToProtocol:@protocol(RACSubscribable)], @"The source must be a subscribable of subscribables. Instead, got %@", x);

			id<RACSubscribable> innerSubscribable = x;
			@synchronized(queuedSubscribables) {
				[queuedSubscribables addObject:innerSubscribable];
			}

			dequeueAndSubscribeIfAllowed();
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			completeSubscribable(self);
		}];

		addDisposable(disposable);

		return [RACDisposable disposableWithBlock:^{
			@synchronized(disposables) {
				[disposables makeObjectsPerformSelector:@selector(dispose)];
			}
		}];
	}];
}

- (id<RACSubscribable>)sequenceNext:(id<RACSubscribable> (^)(void))block {
	NSParameterAssert(block != nil);

	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)concat {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSMutableArray *innerSubscribables = [NSMutableArray array];
		__block RACDisposable *currentDisposable = nil;
		__block BOOL outerDone = NO;
		__block RACSubscriber *innerSubscriber = nil;
		
		void (^startNextInnerSubscribable)(void) = ^{
			if(innerSubscribables.count < 1) return;
			
			id<RACSubscribable> currentInnerSubscribable = [innerSubscribables objectAtIndex:0];
			[innerSubscribables removeObjectAtIndex:0];
			currentDisposable = [currentInnerSubscribable subscribe:innerSubscriber];
		};
		
		void (^sendCompletedIfWeReallyAreDone)(void) = ^{
			if(outerDone && innerSubscribables.count < 1 && currentDisposable == nil) {
				[subscriber sendCompleted];
			}
		};
		
		innerSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			currentDisposable = nil;
			
			startNextInnerSubscribable();
			sendCompletedIfWeReallyAreDone();
		}];
		
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			NSAssert1([x conformsToProtocol:@protocol(RACSubscribable)], @"The source must be a subscribable of subscribables. Instead, got %@", x);
			[innerSubscribables addObject:x];
			
			if(currentDisposable == nil) {
				startNextInnerSubscribable();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			outerDone = YES;
			
			sendCompletedIfWeReallyAreDone();
		}];
		
		return [RACDisposable disposableWithBlock:^{
			innerSubscribables = nil;
			[sourceDisposable dispose];
			[currentDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock {
	NSParameterAssert(startFactory != NULL);
	NSParameterAssert(combineBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)scanWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	NSParameterAssert(combineBlock != NULL);

	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block id runningValue = start;
		[subscriber sendNext:start];

		return [self subscribeNext:^(id x) {
			runningValue = combineBlock(runningValue, x);
			[subscriber sendNext:runningValue];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (id<RACSubscribable>)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	return [self aggregateWithStartFactory:^{
		return start;
	} combine:combineBlock];
}

- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object {
	NSParameterAssert(keyPath != nil);
	NSParameterAssert(object != nil);
	
	__block __unsafe_unretained NSObject *weakObject = object;
	RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
		NSObject *strongObject = weakObject;
		[strongObject setValue:x forKeyPath:keyPath];
	}];
	
	RACDisposable *disposable = [RACDisposable disposableWithBlock:^{
		weakObject = nil;
		[subscriptionDisposable dispose];
	}];

	[object rac_addDeallocDisposable:disposable];

	return disposable;
}

+ (id<RACSubscribable>)interval:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSTimer *timer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(intervalTimerFired:) userInfo:subscriber repeats:YES];
		CFRunLoopAddTimer(CFRunLoopGetMain(), (__bridge CFRunLoopTimerRef)timer, kCFRunLoopCommonModes);

		return [RACDisposable disposableWithBlock:^{
			[timer invalidate];
		}];
	}];
}

+ (void)intervalTimerFired:(NSTimer *)timer {
	RACSubscriber *subscriber = timer.userInfo;
	[subscriber sendNext:NSDate.date];
}

- (id<RACSubscribable>)takeUntil:(id<RACSubscribable>)subscribableTrigger {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *selfDisposable = nil;
		__block RACDisposable *triggerDisposable = [subscribableTrigger subscribe:[RACSubscriber subscriberWithNext:^(id x) {
			[selfDisposable dispose], selfDisposable = nil;
			[subscriber sendCompleted];
		} error:^(NSError *error) {
			
		} completed:^{
			
		}]];
		
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

- (id<RACSubscribable>)takeUntilBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			BOOL stop = predicate(x);
			if(stop) {
				[selfDisposable dispose], selfDisposable = nil;
				[subscriber sendCompleted];
				return;
			}
			
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[selfDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)takeWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != NULL);
	
	return [self takeUntilBlock:^BOOL(id x) {
		return !predicate(x);
	}];
}

- (id<RACSubscribable>)switch {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			NSAssert([x conformsToProtocol:@protocol(RACSubscribable)] || x == nil, @"-switch requires that the source subscribable (%@) send subscribables. Instead we got: %@", self, x);
			
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
		if(error != NULL) *error = e;

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

	[condition unlock];
	return value;
}

+ (id<RACSubscribable>)defer:(id<RACSubscribable> (^)(void))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		id<RACSubscribable> subscribable = block();
		return [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	}];
}

- (id<RACSubscribable>)skipUntilBlock:(BOOL (^)(id x))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block BOOL keepSkipping = YES;
		return [self subscribeNext:^(id x) {
			if(keepSkipping) {
				keepSkipping = !block(x);
			}
			
			if(!keepSkipping) {
				[subscriber sendNext:x];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (id<RACSubscribable>)skipWhileBlock:(BOOL (^)(id x))block {
	NSParameterAssert(block != NULL);
	
	return [self skipUntilBlock:^BOOL(id x) {
		return !block(x);
	}];
}

- (id<RACSubscribable>)distinctUntilChanged {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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
	return [RACSubscribableSequence sequenceWithSubscribable:self];
}

- (RACConnectableSubscribable *)publish {
	return [self multicast:[RACSubject subject]];
}

- (RACConnectableSubscribable *)multicast:(RACSubject *)subject {
	return [RACConnectableSubscribable connectableSubscribableWithSourceSubscribable:self subject:subject];
}

- (id<RACSubscribable>)timeout:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block volatile uint32_t cancelTimeout = 0;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (interval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			if(cancelTimeout) return;
			
			[subscriber sendError:[NSError errorWithDomain:RACSubscribableErrorDomain code:RACSubscribableErrorTimedOut userInfo:nil]];
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

- (id<RACSubscribable>)deliverOn:(RACScheduler *)scheduler {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)subscribeOn:(RACScheduler *)scheduler {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)let:(id<RACSubscribable> (^)(id<RACSubscribable> sharedSubscribable))letBlock {
	NSParameterAssert(letBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		RACConnectableSubscribable *connectable = [self publish];
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

- (id<RACSubscribable>)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
	NSParameterAssert(keyBlock != NULL);

	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableDictionary *groups = [NSMutableDictionary dictionary];

		return [self subscribeNext:^(id x) {
			id<NSCopying> key = keyBlock(x);
			RACGroupedSubscribable *groupSubject = nil;
			@synchronized(groups) {
				groupSubject = [groups objectForKey:key];
				if(groupSubject == nil) {
					groupSubject = [RACGroupedSubscribable subscribableWithKey:key];
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

- (id<RACSubscribable>)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	return [self groupBy:keyBlock transform:nil];
}

- (id<RACSubscribable>)any {	
	return [self any:^(id x) {
		return YES;
	}];
}

- (id<RACSubscribable>)any:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)all:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
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

- (id<RACSubscribable>)retry:(NSInteger)retryCount {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSInteger currentRetryCount = 0;
		
		__block RACDisposable *currentDisposable = nil;
		__block RACSubscriber *innerSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			if(retryCount == 0 || currentRetryCount < retryCount) {
				currentDisposable = [self subscribe:innerSubscriber];
			} else {
				[subscriber sendError:error];
			}
			
			currentRetryCount++;
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		currentDisposable = [self subscribe:innerSubscriber];
		
		return [RACDisposable disposableWithBlock:^{
			[currentDisposable dispose];
		}];
	}];
}

- (id<RACSubscribable>)retry {
	return [self retry:0];
}

- (RACCancelableSubscribable *)asCancelableToSubject:(RACSubject *)subject withBlock:(void (^)(void))block {
	return [RACCancelableSubscribable cancelableSubscribableSourceSubscribable:self subject:subject withBlock:block];
}

- (RACCancelableSubscribable *)asCancelableWithBlock:(void (^)(void))block {
	return [RACCancelableSubscribable cancelableSubscribableSourceSubscribable:self withBlock:block];
}

- (RACCancelableSubscribable *)asCancelable {
	return [self asCancelableWithBlock:NULL];
}

@end
