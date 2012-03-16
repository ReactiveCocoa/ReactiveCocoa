//
//  RACObservable+Querying.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable+Querying.h"
#import "RACObserver.h"
#import "RACSubject.h"
#import "NSObject+GHExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "EXTNil.h"

#define RACCreateWeakSelf __block __unsafe_unretained id weakSelf = self;
#define RACRedefineSelf id self = weakSelf;


@implementation RACObservable (Querying)

- (instancetype)select:(id (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
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
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
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

- (instancetype)do:(void (^)(id x))block {
	NSParameterAssert(block != NULL);

	[self subscribeNext:block];
	return self;
}

- (instancetype)throttle:(NSTimeInterval)interval {	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block id lastDelayedId = nil;
		return [self subscribeNext:^(id x) {
			lastDelayedId = [self performBlock:^{
				[observer sendNext:x];
			} afterDelay:interval];
		} error:^(NSError *error) {
			[self cancelPreviousPerformBlockRequestsWithId:lastDelayedId];
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

- (instancetype)repeat {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[self subscribe:innerObserver];
		}];
		
		return [self subscribe:innerObserver];
	}];
}

- (instancetype)defer {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		__block RACObserver *innerObserver = [RACObserver observerWithNext:^(id x) {
			[observer sendNext:x];
		} error:^(NSError *error) {
			[self subscribe:innerObserver];
		} completed:^{
			[observer sendCompleted];
		}];
		
		return [self subscribe:innerObserver];
	}];
}

- (instancetype)finally:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	[self subscribeNext:^(id _) {
		
	} error:^(NSError *error) {
		block();
	} completed:^{
		block();
	}];
	
	return self;
}

- (instancetype)windowWithStart:(id<RACObservable>)openObservable close:(id<RACObservable> (^)(id<RACObservable> start))closeBlock {
	NSParameterAssert(openObservable != nil);
	NSParameterAssert(closeBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
				
		__block RACSubject *currentWindow = nil;
		__block id<RACObservable> currentCloseWindow = nil;
		__block RACDisposable *closeObserverDisposable = NULL;
		
		void (^closeCurrentWindow)(void) = ^{
			[currentWindow sendCompleted];
			currentWindow = nil;
			currentCloseWindow = nil;
			[closeObserverDisposable dispose], closeObserverDisposable = nil;
		};
		
		RACDisposable *openObserverDisposable = [openObservable subscribe:[RACObserver observerWithNext:^(id x) {
			if(currentWindow == nil) {
				currentWindow = [RACSubject subject];
				[observer sendNext:currentWindow];
				
				currentCloseWindow = closeBlock(currentWindow);
				closeObserverDisposable = [currentCloseWindow subscribe:[RACObserver observerWithNext:^(id x) {
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
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		RACBehaviorSubject *windowOpenSubject = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@""];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		__block NSUInteger valuesReceived = 0;
		return [[self windowWithStart:windowOpenSubject close:^(id<RACObservable> start) {
			return windowCloseSubject;
		}] subscribeNext:^(id x) {		
			[x subscribeNext:^(id x) {
				valuesReceived++;
				if(valuesReceived % bufferCount == 0) {
					[windowCloseSubject sendNext:x];
					[windowOpenSubject sendNext:@""];
				}
			} error:^(NSError *error) {
				
			} completed:^{
				
			}];
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
	}];
}

- (instancetype)take:(NSUInteger)count {
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		
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
	
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableSet *completedObservables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableDictionary *lastValues = [NSMutableDictionary dictionaryWithCapacity:observables.count];
		for(id<RACObservable> observable in observables) {
			RACDisposable *disposable = [observable subscribe:[RACObserver observerWithNext:^(id x) {
				[lastValues setObject:x ? : [EXTNil null] forKey:[NSString stringWithFormat:@"%p", observable]];
				
				if(lastValues.count == observables.count) {
					NSMutableArray *orderedValues = [NSMutableArray arrayWithCapacity:observables.count];
					for(id<RACObservable> o in observables) {
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
			
			[disposables addObject:disposable];
		}
		
		return [RACDisposable disposableWithBlock:^{
			for(RACDisposable *disposable in disposables) {
				[disposable dispose];
			}
		}];
	}];
}

+ (instancetype)merge:(NSArray *)observables {
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:observables.count];
		NSMutableSet *completedObservables = [NSMutableSet setWithCapacity:observables.count];
		for(id<RACObservable> observable in observables) {
			RACDisposable *disposable = [observable subscribe:[RACObserver observerWithNext:^(id x) {
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

- (instancetype)selectMany:(id<RACObservable> (^)(id x))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	RACCreateWeakSelf
	return [RACObservable createObservable:^(id<RACObserver> observer) {
		RACRedefineSelf
		NSMutableSet *activeObservables = [NSMutableSet set];
		[activeObservables addObject:self];
		
		NSMutableSet *completedObservables = [NSMutableSet set];
		RACDisposable *outerDisposable = [self subscribeNext:^(id x) {
			id<RACObservable> observable = selectBlock(x);
			[activeObservables addObject:observable];
			[observable subscribe:[RACObserver observerWithNext:^(id x) {
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

@end
