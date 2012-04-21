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

NSString * const RACSubscribableErrorDomain = @"RACSubscribableErrorDomain";


@implementation RACSubscribable (Operations)

- (RACSubscribable *)select:(id (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		return [self subscribeNext:^(id x) {
			[observer sendNext:selectBlock(x)];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (RACSubscribable *)where:(BOOL (^)(id x))whereBlock {
	NSParameterAssert(whereBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		return [self subscribeNext:^(id x) {
			if(whereBlock(x)) {
				[observer sendNext:x];
			}
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (RACSubscribable *)doNext:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		return [self subscribeNext:^(id x) {
			block(x);
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (RACSubscribable *)throttle:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			if(lastDelayedId != nil) [self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			lastDelayedId = [self rac_performBlock:^{
				[observer sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (RACSubscribable *)delay:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			lastDelayedId = [self rac_performBlock:^{
				[observer sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self rac_cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (RACSubscribable *)repeat {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block RACDisposable *currentDisposable = nil;
		
		__block RACSubscriber *innerObserver = [RACSubscriber subscriberWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
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
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block RACDisposable *currentDisposable = nil;
		
		__block RACSubscriber *innerObserver = [RACSubscriber subscriberWithNext:^(id x) {
			[observer sendNext:[RACMaybe maybeWithObject:x]];
		} error:^(NSError *error) {
			[observer sendNext:[RACMaybe maybeWithError:error]];
			currentDisposable = [self subscribe:innerObserver];
		} completed:^{
			[observer sendCompleted];
		}];
		
		currentDisposable = [self subscribe:innerObserver];
		
		return [RACDisposable disposableWithBlock:^{
			[currentDisposable dispose];
		}];
	}];
}

- (RACSubscribable *)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock {
	NSParameterAssert(catchBlock != NULL);
		
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {			
			id<RACSubscribable> observable = catchBlock(error);
			innerDisposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[observer sendNext:x];
			} error:^(NSError *error) {
				[observer sendError:error];
			} completed:^{
				[observer sendCompleted];
			}]];
		} completed:^{
			[observer sendCompleted];
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
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		return [self subscribeNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
			block();
		} completed:^{
			[observer sendCompleted];
			block();
		}];
	}];
}

- (RACSubscribable *)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock {
	NSParameterAssert(openSubscribable != nil);
	NSParameterAssert(closeBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
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
				[observer sendNext:currentWindow];
				
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
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
				
		return [RACDisposable disposableWithBlock:^{
			[closeObserverDisposable dispose];
			[openObserverDisposable dispose];
			[selfObserverDisposable dispose];
		}];
	}];
}

- (RACSubscribable *)buffer:(NSUInteger)bufferCount {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:bufferCount];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(id<RACSubscribable> start) {
			return windowCloseSubject;
		}] subscribeNext:^(id x) {		
			innerDisposable = [x subscribeNext:^(id x) {
				if(values.count % bufferCount == 0) {
					[observer sendNext:x];
					[windowCloseSubject sendNext:[RACUnit defaultUnit]];
					[windowOpenSubject sendNext:[RACUnit defaultUnit]];
				}
			}];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	}];
}

- (RACSubscribable *)bufferWithTime:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableArray *values = [NSMutableArray array];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(id<RACSubscribable> start) {
			return [[[RACSubscribable interval:interval] take:1] doNext:^(id x) {
				[observer sendNext:[RACTuple tupleWithObjectsFromArray:values convertNullsToNils:YES]];
				[values removeAllObjects];
				[windowOpenSubject sendNext:[RACUnit defaultUnit]];
			}];
		}] subscribeNext:^(id x) {
			innerDisposable = [x subscribeNext:^(id x) {
				[values addObject:x ? : [RACTupleNil tupleNil]];
			}];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	}];
}

- (RACSubscribable *)take:(NSUInteger)count {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {		
		__block NSUInteger valuesTaken = 0;
		return [self subscribeNext:^(id x) {
			valuesTaken++;
			[observer sendNext:x];
			
			if(valuesTaken >= count) {
				[observer sendCompleted];
			}
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

+ (RACSubscribable *)combineLatest:(NSArray *)observables reduce:(id (^)(RACTuple *xs))reduceBlock {
	NSParameterAssert(reduceBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableSet *completedObservables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableDictionary *lastValues = [NSMutableDictionary dictionaryWithCapacity:observables.count];
		for(id<RACSubscribable> observable in observables) {
			RACDisposable *disposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[lastValues setObject:x ? : [RACTupleNil tupleNil] forKey:[NSString stringWithFormat:@"%p", observable]];
				
				if(lastValues.count == observables.count) {
					NSMutableArray *orderedValues = [NSMutableArray arrayWithCapacity:observables.count];
					for(id<RACSubscribable> o in observables) {
						[orderedValues addObject:[lastValues objectForKey:[NSString stringWithFormat:@"%p", o]]];
					}
					
					[observer sendNext:reduceBlock([RACTuple tupleWithObjectsFromArray:orderedValues])];
				}
			} error:^(NSError *error) {
				[observer sendError:error];
			} completed:^{
				[completedObservables addObject:observable];
				if(completedObservables.count == observables.count) {
					[observer sendCompleted];
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

+ (RACSubscribable *)whenAll:(NSArray *)observables {
	return [self combineLatest:observables reduce:^(RACTuple *xs) { return [RACUnit defaultUnit]; }];
}

+ (RACSubscribable *)merge:(NSArray *)observables {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableSet *completedObservables = [NSMutableSet setWithCapacity:observables.count];
		for(id<RACSubscribable> observable in observables) {
			RACDisposable *disposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[observer sendNext:x];
			} error:^(NSError *error) {
				[observer sendError:error];
			} completed:^{
				[completedObservables addObject:observable];
				if(completedObservables.count == observables.count) {
					[observer sendCompleted];
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

- (RACSubscribable *)selectMany:(id<RACSubscribable> (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableSet *activeObservables = [NSMutableSet set];
		[activeObservables addObject:self];
		
		NSMutableSet *completedObservables = [NSMutableSet set];
		NSMutableSet *innerDisposables = [NSMutableSet set];
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			id<RACSubscribable> observable = selectBlock(x);
			[activeObservables addObject:observable];
			RACDisposable *disposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[observer sendNext:x];
			} error:^(NSError *error) {
				[observer sendError:error];
			} completed:^{
				[completedObservables addObject:observable];
				
				if(completedObservables.count == activeObservables.count) {
					[observer sendCompleted];
				}
			}]];
			
			[innerDisposables addObject:disposable];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[completedObservables addObject:self];
			
			if(completedObservables.count == activeObservables.count) {
				[observer sendCompleted];
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

- (RACSubscribable *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block id runningValue = start;
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
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(intervalTimerFired:) userInfo:observer repeats:YES];
		
		return [RACDisposable disposableWithBlock:^{
			[observer sendCompleted];
			[timer invalidate];
		}];
	}];
}

+ (void)intervalTimerFired:(NSTimer *)timer {
	id<RACSubscriber> observer = [timer userInfo];
	[observer sendNext:[RACUnit defaultUnit]];
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
			BOOL keepTaking = predicate(x);
			if(!keepTaking) {
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
	__block id value = defaultValue;
	__block BOOL stop = NO;
	__block RACDisposable *disposable = [self subscribeNext:^(id x) {
		value = x;
		stop = YES;
		[disposable dispose];
	} error:^(NSError *error) {
		stop = YES;
	} completed:^{
		stop = YES;
	}];
	
	while(!stop) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	}
	
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

@end
