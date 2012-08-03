//
//  RACSubscribable+Operations.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable+Operations.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "NSObject+RACExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACUnit.h"
#import "RACMaybe.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACTuple.h"
#import "RACScheduler.h"
#import "RACGroupedSubscribable.h"
#import "RACCancelableSubscribable+Private.h"

NSString * const RACSubscribableErrorDomain = @"RACSubscribableErrorDomain";


@implementation RACSubscribable (Operations)

- (RACSubscribable *)select:(id (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:selectBlock(x)];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSubscribable *)injectObjectWeakly:(id)object {
	__block __unsafe_unretained id weakObject = object;
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

- (RACSubscribable *)where:(BOOL (^)(id x))whereBlock {
	NSParameterAssert(whereBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			if(whereBlock(x)) {
				[subscriber sendNext:x];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSubscribable *)doNext:(void (^)(id x))block {
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

- (RACSubscribable *)throttle:(NSTimeInterval)interval {
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

- (RACSubscribable *)delay:(NSTimeInterval)interval {
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

- (RACSubscribable *)repeat {
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

- (RACSubscribable *)asMaybes {
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

- (RACSubscribable *)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock {
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

- (RACSubscribable *)catchTo:(id<RACSubscribable>)subscribable {
	return [self catch:^(NSError *error) {
		return subscribable;
	}];
}

- (RACSubscribable *)finally:(void (^)(void))block {
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

- (RACSubscribable *)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock {
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

- (RACSubscribable *)buffer:(NSUInteger)bufferCount {
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

- (RACSubscribable *)bufferWithTime:(NSTimeInterval)interval {
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

- (RACSubscribable *)take:(NSUInteger)count {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {		
		__block NSUInteger valuesTaken = 0;
		return [self subscribeNext:^(id x) {
			valuesTaken++;
			[subscriber sendNext:x];
			
			if(valuesTaken >= count) {
				[subscriber sendCompleted];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSubscribable *)takeLast:(NSUInteger)count {
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

+ (RACSubscribable *)combineLatest:(NSArray *)subscribables reduce:(id (^)(RACTuple *xs))reduceBlock {
	NSParameterAssert(reduceBlock != NULL);
	
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
						
						[subscriber sendNext:reduceBlock([RACTuple tupleWithObjectsFromArray:orderedValues])];
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

+ (RACSubscribable *)whenAll:(NSArray *)subscribables {
	return [self combineLatest:subscribables reduce:^(RACTuple *xs) { return [RACUnit defaultUnit]; }];
}

+ (RACSubscribable *)merge:(NSArray *)subscribables {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:subscribables.count];
		NSMutableSet *completedSubscribables = [NSMutableSet setWithCapacity:subscribables.count];
		for(id<RACSubscribable> subscribable in subscribables) {
			RACDisposable *disposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
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
			
			[disposables addObject:disposable];
		}
		
		return [RACDisposable disposableWithBlock:^{
			for(RACDisposable *disposable in disposables) {
				[disposable dispose];
			}
		}];
	}];
}

- (RACSubscribable *)merge:(RACSubscribable *)subscribable {
	return [[self class] merge:[NSArray arrayWithObjects:self, subscribable, nil]];
}

- (RACSubscribable *)merge {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		NSMutableSet *activeSubscribables = [NSMutableSet set];
		[activeSubscribables addObject:self];
		
		NSMutableSet *completedSubscribables = [NSMutableSet set];
		NSMutableSet *innerDisposables = [NSMutableSet set];
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			NSAssert1([x conformsToProtocol:@protocol(RACSubscribable)], @"The source must be a subscribable of subscribables. Instead, got %@", x);
			
			id<RACSubscribable> innerSubscribable = x;
			@synchronized(activeSubscribables) {
				[activeSubscribables addObject:innerSubscribable];
			}
			
			RACDisposable *disposable = [innerSubscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@synchronized(completedSubscribables) {
					[completedSubscribables addObject:innerSubscribable];
					
					@synchronized(activeSubscribables) {
						if(completedSubscribables.count == activeSubscribables.count) {
							[subscriber sendCompleted];
						}
					}
				}
			}]];
			
			[innerDisposables addObject:disposable];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized(completedSubscribables) {
				[completedSubscribables addObject:self];
				
				@synchronized(activeSubscribables) {
					if(completedSubscribables.count == activeSubscribables.count) {
						[subscriber sendCompleted];
					}
				}
			}
		}];
		
		return [RACDisposable disposableWithBlock:^{
			for(RACDisposable *innerDisposable in innerDisposables) {
				[innerDisposable dispose];
			}
			[outerDisposable dispose];
		}];
	}];
}

- (RACSubscribable *)selectMany:(id<RACSubscribable> (^)(id x))selectBlock {
	return [[self select:selectBlock] merge];
}

- (RACSubscribable *)concat:(id<RACSubscribable>)subscribable {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *concattedDisposable = nil;
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			concattedDisposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
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

- (RACSubscribable *)concat {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSMutableArray *innerSubscribables = [NSMutableArray array];
		__block RACDisposable *currentDisposable = nil;
		__block BOOL outerDone = NO;
		__block RACSubscriber *innerSubscriber = nil;
		
		void (^startNextInnerSubscribable)(void) = ^{
			if(innerSubscribables.count < 1) return;
			
			RACSubscribable *currentInnerSubscribable = [innerSubscribables objectAtIndex:0];
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

- (RACSubscribable *)scanWithStart:(NSInteger)start combine:(NSInteger (^)(NSInteger running, NSInteger next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSInteger runningValue = start;
		return [self subscribeNext:^(id x) {
			runningValue = combineBlock(runningValue, [x integerValue]);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:[NSNumber numberWithInteger:runningValue]];
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSubscribable *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock {
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

- (RACSubscribable *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
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
	
	return [RACDisposable disposableWithBlock:^{
		weakObject = nil;
		[subscriptionDisposable dispose];
	}];
}

- (RACSubscribable *)startWith:(id)initialValue {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {		
		[subscriber sendNext:initialValue];
		
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

+ (RACSubscribable *)interval:(NSTimeInterval)interval {
	__block RACSubscribable *subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		__block BOOL stop = NO;
		
		dispatch_time_t (^nextFutureTime)(void) = ^{
			return dispatch_time(DISPATCH_TIME_NOW, (int64_t) (interval * NSEC_PER_SEC));
		};
		
		__block void (^sendNext)(void) = ^{
			if(stop) return;
			
			[subscriber sendNext:[RACUnit defaultUnit]];
			
			dispatch_after(nextFutureTime(), dispatch_get_current_queue(), sendNext);
		};
		
		dispatch_after(nextFutureTime(), dispatch_get_current_queue(), sendNext);
		
		return [RACDisposable disposableWithBlock:^{
			stop = YES;
		}];
	}];
	
	return subscribable;
}

- (RACSubscribable *)takeUntil:(id<RACSubscribable>)subscribableTrigger {
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

- (RACSubscribable *)takeUntilBlock:(BOOL (^)(id x))predicate {
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

- (RACSubscribable *)takeWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != NULL);
	
	return [self takeUntilBlock:^BOOL(id x) {
		return !predicate(x);
	}];
}

- (RACSubscribable *)switch {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			NSAssert2([x conformsToProtocol:@protocol(RACSubscribable)], @"-switch requires that the source subscribable (%@) send subscribables. Instead we got: %@", self, x);
			
			[innerDisposable dispose], innerDisposable = nil;
			
			innerDisposable = [x subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				
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
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

	__block id value = defaultValue;
	__block RACDisposable *disposable = [self subscribeNext:^(id x) {
		value = x;
		if(success != NULL) *success = YES;

		// Only signal after setting values that aren't thread-safe.
		dispatch_semaphore_signal(semaphore);
		[disposable dispose];
	} error:^(NSError *e) {
		if(success != NULL) *success = NO;
		if(error != NULL) *error = e;

		dispatch_semaphore_signal(semaphore);
	} completed:^{
		if(success != NULL) *success = YES;

		dispatch_semaphore_signal(semaphore);
	}];

	dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
	
	dispatch_release(semaphore);
	return value;
}

+ (RACSubscribable *)defer:(id<RACSubscribable> (^)(void))block {
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

- (RACSubscribable *)skip:(NSUInteger)skipCount {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSUInteger skipped = 0;
		return [self subscribeNext:^(id x) {
			if(skipped >= skipCount) {
				[subscriber sendNext:x];
			}
			
			skipped++;
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSubscribable *)skipUntilBlock:(BOOL (^)(id x))block {
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

- (RACSubscribable *)skipWhileBlock:(BOOL (^)(id x))block {
	NSParameterAssert(block != NULL);
	
	return [self skipUntilBlock:^BOOL(id x) {
		return !block(x);
	}];
}

- (RACSubscribable *)distinctUntilChanged {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block id lastValue = nil;
		return [self subscribeNext:^(id x) {
			if(![x isEqual:lastValue]) {
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
	NSMutableArray *values = [NSMutableArray array];
	__block BOOL stop = NO;
	[self subscribeNext:^(id x) {
		[values addObject:x ? : [NSNull null]];
	} error:^(NSError *error) {
		stop = YES;
	} completed:^{
		stop = YES;
	}];
	
	while(!stop) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	}
	
	return values;
}

- (RACConnectableSubscribable *)publish {
	return [self multicast:[RACSubject subject]];
}

- (RACConnectableSubscribable *)multicast:(RACSubject *)subject {
	return [RACConnectableSubscribable connectableSubscribableWithSourceSubscribable:self subject:subject];
}

- (RACSubscribable *)timeout:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		id delayedIdentifier = [self rac_performBlock:^{
			[subscriber sendError:[NSError errorWithDomain:RACSubscribableErrorDomain code:RACSubscribableErrorTimedOut userInfo:nil]];
		} afterDelay:interval];
		
		RACDisposable *disposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[self rac_cancelPreviousPerformBlockRequestsWithId:delayedIdentifier];
			[subscriber sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[self rac_cancelPreviousPerformBlockRequestsWithId:delayedIdentifier];
			[disposable dispose];
		}];
	}];
}

- (RACSubscribable *)deliverOn:(RACScheduler *)scheduler {
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

- (RACSubscribable *)subscribeOn:(RACScheduler *)scheduler {
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

- (RACSubscribable *)let:(RACSubscribable * (^)(RACSubscribable *sharedSubscribable))letBlock {
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

- (RACSubscribable *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
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

- (RACSubscribable *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	return [self groupBy:keyBlock transform:nil];
}

- (RACSubscribable *)any {	
	return [self any:^(id x) {
		return YES;
	}];
}

- (RACSubscribable *)any:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *disposable = [self subscribeNext:^(id x) {
			if(predicateBlock(x)) {
				[subscriber sendNext:[NSNumber numberWithBool:YES]];
				[subscriber sendCompleted];
				[disposable dispose];
			}
		} error:^(NSError *error) {
			[subscriber sendNext:[NSNumber numberWithBool:NO]];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:[NSNumber numberWithBool:NO]];
			[subscriber sendCompleted];
		}];
		
		return disposable;
	}];
}

- (RACSubscribable *)all:(BOOL (^)(id object))predicateBlock {
	NSParameterAssert(predicateBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *disposable = [self subscribeNext:^(id x) {
			if(!predicateBlock(x)) {
				[subscriber sendNext:[NSNumber numberWithBool:NO]];
				[subscriber sendCompleted];
				[disposable dispose];
			}
		} error:^(NSError *error) {
			[subscriber sendNext:[NSNumber numberWithBool:NO]];
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:[NSNumber numberWithBool:YES]];
			[subscriber sendCompleted];
		}];
		
		return disposable;
	}];
}

- (RACSubscribable *)retry:(NSInteger)retryCount {
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

- (RACSubscribable *)retry {
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
