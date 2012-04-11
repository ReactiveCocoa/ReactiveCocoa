//
//  RACSubscribable+Operations.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable+Operations.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "NSObject+RACExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "EXTNil.h"
#import "RACUnit.h"
#import "RACMaybe.h"


@implementation RACSubscribable (Operations)

- (instancetype)select:(id (^)(id x))selectBlock {
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

- (instancetype)where:(BOOL (^)(id x))whereBlock {
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

- (instancetype)doNext:(void (^)(id x))block {
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

- (instancetype)throttle:(NSTimeInterval)interval {	
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

- (instancetype)delay:(NSTimeInterval)interval {
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

- (instancetype)repeat {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block RACDisposable *currentDisposable = nil;
		
		__block RACSubscriber *innerObserver = [RACSubscriber subscriberWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[self subscribe:innerObserver];
		}];
		
		currentDisposable = [self subscribe:innerObserver];
		
		return [RACDisposable disposableWithBlock:^{
			[currentDisposable dispose];
		}];
	}];
}

- (instancetype)catchToMaybe {
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

- (instancetype)catch:(id<RACSubscribable> (^)(NSError *error))catchBlock {
	NSParameterAssert(catchBlock != NULL);
		
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {			
			id<RACSubscribable> observable = catchBlock(error);
			innerDisposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[observer sendNext:x];
				[innerDisposable dispose], innerDisposable = nil;
			} error:NULL completed:NULL]];
		} completed:^{
			[observer sendCompleted];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[outerDisposable dispose];
		}];
	}];
}

- (instancetype)catchTo:(id<RACSubscribable>)subscribable {
	return [self catch:^(NSError *error) {
		return subscribable;
	}];
}

- (instancetype)finally:(void (^)(void))block {
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

- (instancetype)windowWithStart:(id<RACSubscribable>)openSubscribable close:(id<RACSubscribable> (^)(id<RACSubscribable> start))closeBlock {
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

- (instancetype)buffer:(NSUInteger)bufferCount {
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

- (instancetype)bufferWithTime:(NSTimeInterval)interval {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableArray *values = [NSMutableArray array];
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:[RACUnit defaultUnit]];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:windowOpenSubject close:^(id<RACSubscribable> start) {
			return [[[RACSubscribable interval:interval] take:1] doNext:^(id x) {
				[observer sendNext:values];
				[values removeAllObjects];
				[windowOpenSubject sendNext:[RACUnit defaultUnit]];
			}];
		}] subscribeNext:^(id x) {
			innerDisposable = [x subscribeNext:^(id x) {
				[values addObject:x ? : [EXTNil null]];
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

- (instancetype)take:(NSUInteger)count {
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

+ (instancetype)combineLatest:(NSArray *)observables reduce:(id (^)(NSArray *xs))reduceBlock {
	NSParameterAssert(reduceBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableSet *completedObservables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableDictionary *lastValues = [NSMutableDictionary dictionaryWithCapacity:observables.count];
		for(id<RACSubscribable> observable in observables) {
			RACDisposable *disposable = [observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[lastValues setObject:x ? : [EXTNil null] forKey:[NSString stringWithFormat:@"%p", observable]];
				
				if(lastValues.count == observables.count) {
					NSMutableArray *orderedValues = [NSMutableArray arrayWithCapacity:observables.count];
					for(id<RACSubscribable> o in observables) {
						[orderedValues addObject:[lastValues objectForKey:[NSString stringWithFormat:@"%p", o]]];
					}
					
					[observer sendNext:reduceBlock(orderedValues)];
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

+ (instancetype)whenAll:(NSArray *)observables {
	return [self combineLatest:observables reduce:^(NSArray *xs) { return [RACUnit defaultUnit]; }];
}

+ (instancetype)merge:(NSArray *)observables {
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

- (instancetype)selectMany:(id<RACSubscribable> (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> observer) {
		NSMutableSet *activeObservables = [NSMutableSet set];
		[activeObservables addObject:self];
		
		NSMutableSet *completedObservables = [NSMutableSet set];
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			id<RACSubscribable> observable = selectBlock(x);
			[activeObservables addObject:observable];
			[observable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				[observer sendNext:x];
			} error:^(NSError *error) {
				[observer sendError:error];
			} completed:^{
				[completedObservables addObject:observable];
				
				if(completedObservables.count == activeObservables.count) {
					[observer sendCompleted];
				}
			}]];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[completedObservables addObject:self];
			
			if(completedObservables.count == activeObservables.count) {
				[observer sendCompleted];
			}
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[outerDisposable dispose];
		}];
	}];
}

- (instancetype)concat:(id<RACSubscribable>)subscribable {
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

- (instancetype)scanWithStart:(NSInteger)start combine:(NSInteger (^)(NSInteger running, NSInteger next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block NSInteger runningValue = start;
		return [self subscribeNext:^(id x) {
			runningValue = combineBlock(runningValue, [x integerValue]);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
			[subscriber sendNext:[NSNumber numberWithInteger:runningValue]];
		}];
	}];
}

- (instancetype)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
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

- (instancetype)startWith:(id)initialValue {
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

+ (instancetype)interval:(NSTimeInterval)interval {
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

- (instancetype)takeUntil:(id<RACSubscribable>)subscribableTrigger {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		RACDisposable *triggerDisposable = [subscribableTrigger subscribe:[RACSubscriber subscriberWithNext:^(id x) {
			[selfDisposable dispose], selfDisposable = nil;
			[subscriber sendCompleted];
		} error:^(NSError *error) {
			
		} completed:^{
			
		}]];
		
		return [RACDisposable disposableWithBlock:^{
			[triggerDisposable dispose];
			[selfDisposable dispose];
		}];
	}];
}

- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate {
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

- (instancetype)switch {
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

+ (instancetype)defer:(id<RACSubscribable> (^)(void))block {
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

- (instancetype)skip:(NSUInteger)skipCount {
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

- (instancetype)distinctUntilChanged {
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
		[values addObject:x ? : [EXTNil null]];
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

@end
