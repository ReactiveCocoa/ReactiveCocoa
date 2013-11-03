//
//  RACSignal+Operations.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal+Operations.h"
#import "EXTScope.h"
#import "NSArray+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACGroupedSignal.h"
#import "RACMulticastConnection+Private.h"
#import "RACReplaySubject.h"
#import "RACScheduler+Private.h"
#import "RACScheduler.h"
#import "RACSerialDisposable.h"
#import "RACSignalSequence.h"
#import "RACStream+Private.h"
#import "RACSubject.h"
#import "RACSubscriber+Private.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

NSString * const RACSignalErrorDomain = @"RACSignalErrorDomain";

const NSInteger RACSignalErrorTimedOut = 1;
const NSInteger RACSignalErrorNoMatchingCase = 2;

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

		RACDisposable *subscriptionDisposable = [signal subscribeNext:next error:^(NSError *e) {
			@autoreleasepool {
				error(e, compoundDisposable);
				[compoundDisposable removeDisposable:weakSelfDisposable];
			}

			recurse();
		} completed:^{
			@autoreleasepool {
				completed(compoundDisposable);
				[compoundDisposable removeDisposable:weakSelfDisposable];
			}

			recurse();
		}];

		[selfDisposable addDisposable:subscriptionDisposable];
	};
	
	// Subscribe once immediately, and then use recursive scheduling for any
	// further resubscriptions.
	recursiveBlock(^{
		RACScheduler *recursiveScheduler = RACScheduler.currentScheduler ?: [RACScheduler scheduler];

		RACDisposable *schedulingDisposable = [recursiveScheduler scheduleRecursiveBlock:recursiveBlock];
		[compoundDisposable addDisposable:schedulingDisposable];
	});

	return compoundDisposable;
}

@implementation RACSignal (Operations)

- (RACSignal *)concat:(RACSignal *)signal {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[signal subscribe:subscriber];
		}]];
	}] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

- (RACSignal *)flattenMap:(RACSignal * (^)(id value))block {
	return [super flattenMap:block];
}

- (RACSignal *)flatten {
	return [super flatten];
}

- (RACSignal *)map:(id (^)(id value))block {
	return [super map:block];
}

- (RACSignal *)mapReplace:(id)object {
	return [super mapReplace:object];
}

- (RACSignal *)filter:(BOOL (^)(id value))block {
	return [super filter:block];
}

- (RACSignal *)ignore:(id)value {
	return [super ignore:value];
}

- (RACSignal *)reduceEach:(id (^)())reduceBlock {
	return [super reduceEach:reduceBlock];
}

- (RACSignal *)startWith:(id)value {
	return [super startWith:value];
}

- (RACSignal *)skip:(NSUInteger)skipCount {
	return [super skip:skipCount];
}

- (RACSignal *)take:(NSUInteger)count {
	return [super take:count];
}

- (RACSignal *)zipWith:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		__block BOOL selfCompleted = NO;
		NSMutableArray *selfValues = [NSMutableArray array];

		__block BOOL otherCompleted = NO;
		NSMutableArray *otherValues = [NSMutableArray array];

		void (^sendCompletedIfNecessary)(void) = ^{
			@synchronized (selfValues) {
				BOOL selfEmpty = (selfCompleted && selfValues.count == 0);
				BOOL otherEmpty = (otherCompleted && otherValues.count == 0);
				if (selfEmpty || otherEmpty) [subscriber sendCompleted];
			}
		};

		void (^sendNext)(void) = ^{
			@synchronized (selfValues) {
				if (selfValues.count == 0) return;
				if (otherValues.count == 0) return;

				RACTuple *tuple = [RACTuple tupleWithObjects:selfValues[0], otherValues[0], nil];
				[selfValues removeObjectAtIndex:0];
				[otherValues removeObjectAtIndex:0];

				[subscriber sendNext:tuple];
				sendCompletedIfNecessary();
			}
		};

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			@synchronized (selfValues) {
				[selfValues addObject:x ?: RACTupleNil.tupleNil];
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (selfValues) {
				selfCompleted = YES;
				sendCompletedIfNecessary();
			}
		}]];

		[subscriber.disposable addDisposable:[signal subscribeNext:^(id x) {
			@synchronized (selfValues) {
				[otherValues addObject:x ?: RACTupleNil.tupleNil];
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (selfValues) {
				otherCompleted = YES;
				sendCompletedIfNecessary();
			}
		}]];
	}] setNameWithFormat:@"[%@] -zipWith: %@", self.name, signal];
}

// For some reason, only the overrides of class methods trigger this warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

+ (RACSignal *)zip:(id<NSFastEnumeration>)streams {
	return [super zip:streams];
}

+ (RACSignal *)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock {
	return [super zip:streams reduce:reduceBlock];
}

+ (RACSignal *)concat:(id<NSFastEnumeration>)streams {
	return [super concat:streams];
}

#pragma clang diagnostic pop

- (RACSignal *)scanWithStart:(id)startingValue reduce:(id (^)(id running, id next))block {
	return [super scanWithStart:startingValue reduce:block];
}

- (RACSignal *)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id current))reduceBlock {
	return [super combinePreviousWithStart:start reduce:reduceBlock];
}

- (RACSignal *)takeUntilBlock:(BOOL (^)(id x))predicate {
	return [super takeUntilBlock:predicate];
}

- (RACSignal *)takeWhileBlock:(BOOL (^)(id x))predicate {
	return [super takeWhileBlock:predicate];
}

- (RACSignal *)skipUntilBlock:(BOOL (^)(id x))predicate {
	return [super skipUntilBlock:predicate];
}

- (RACSignal *)skipWhileBlock:(BOOL (^)(id x))predicate {
	return [super skipWhileBlock:predicate];
}

- (RACSignal *)distinctUntilChanged {
	return [super distinctUntilChanged];
}

- (RACSignal *)doNext:(void (^)(id x))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			block(x);
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -doNext:", self.name];
}

- (RACSignal *)doError:(void (^)(NSError *error))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			block(error);
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -doError:", self.name];
}

- (RACSignal *)doCompleted:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			block();
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -doCompleted:", self.name];
}

- (RACSignal *)doDisposed:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:block]];
		[self subscribe:subscriber];
	}] setNameWithFormat:@"[%@] -doDisposed:", self.name];
}

- (RACSignal *)doFinished:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[[self
		doError:^(NSError *error) {
			block();
		}]
		doCompleted:^{
			block();
		}]
		setNameWithFormat:@"[%@] -doFinished:", self.name];
}

- (RACSignal *)doSubscribed:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[self subscribe:subscriber];
		block();
	}] setNameWithFormat:@"[%@] -doSubscribed:", self.name];
}

- (RACSignal *)throttle:(NSTimeInterval)interval {
	return [[self throttle:interval valuesPassingTest:^(id _) {
		return YES;
	}] setNameWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
}

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate {
	NSCParameterAssert(interval >= 0);
	NSCParameterAssert(predicate != nil);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		// Information about any currently-buffered `next` event.
		__block id nextValue = nil;
		__block BOOL hasNextValue = NO;

		RACSerialDisposable *nextDisposable = [[RACSerialDisposable alloc] init];
		[subscriber.disposable addDisposable:nextDisposable];

		void (^flushNext)(BOOL send) = ^(BOOL send) {
			@synchronized (subscriber) {
				[nextDisposable.disposable dispose];

				if (!hasNextValue) return;
				if (send) [subscriber sendNext:nextValue];

				nextValue = nil;
				hasNextValue = NO;
			}
		};

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
			BOOL shouldThrottle = predicate(x);

			@synchronized (subscriber) {
				flushNext(NO);
				if (!shouldThrottle) {
					[subscriber sendNext:x];
					return;
				}

				nextValue = x;
				hasNextValue = YES;
				nextDisposable.disposable = [delayScheduler afterDelay:interval schedule:^{
					flushNext(YES);
				}];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			flushNext(YES);
			[subscriber sendCompleted];
		}];

		[subscriber.disposable addDisposable:subscriptionDisposable];
	}] setNameWithFormat:@"[%@] -throttle: %f valuesPassingTest:", self.name, (double)interval];
}

- (RACSignal *)delay:(NSTimeInterval)interval {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
			[subscriber.disposable addDisposable:[delayScheduler afterDelay:interval schedule:block]];
		};

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			schedule(^{
				[subscriber sendNext:x];
			});
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			schedule(^{
				[subscriber sendCompleted];
			});
		}]];
	}] setNameWithFormat:@"[%@] -delay: %f", self.name, (double)interval];
}

- (RACSignal *)repeat {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *disposable = subscribeForever(self,
			^(id x) {
				[subscriber sendNext:x];
			},
			^(NSError *error, RACDisposable *disposable) {
				[subscriber sendError:error];
			},
			^(RACDisposable *disposable) {
				// Resubscribe.
			});

		[subscriber.disposable addDisposable:disposable];
	}] setNameWithFormat:@"[%@] -repeat", self.name];
}

- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
	NSCParameterAssert(catchBlock != NULL);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			RACSignal *signal = catchBlock(error);
			NSCAssert(signal != nil, @"Expected non-nil signal from catch block on %@", self);

			[signal subscribe:subscriber];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -catch:", self.name];
}

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameWithFormat:@"[%@] -catchTo: %@", self.name, signal];
}

- (RACSignal *)try:(BOOL (^)(id value, NSError **errorPtr))tryBlock {
	NSCParameterAssert(tryBlock != NULL);
	
	return [[self flattenMap:^(id value) {
		NSError *error = nil;
		BOOL passed = tryBlock(value, &error);
		return (passed ? [RACSignal return:value] : [RACSignal error:error]);
	}] setNameWithFormat:@"[%@] -try:", self.name];
}

- (RACSignal *)tryMap:(id (^)(id value, NSError **errorPtr))mapBlock {
	NSCParameterAssert(mapBlock != NULL);
	
	return [[self flattenMap:^(id value) {
		NSError *error = nil;
		id mappedValue = mapBlock(value, &error);
		return (mappedValue == nil ? [RACSignal error:error] : [RACSignal return:mappedValue]);
	}] setNameWithFormat:@"[%@] -tryMap:", self.name];
}

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *timerDisposable = [[RACSerialDisposable alloc] init];
		[subscriber.disposable addDisposable:timerDisposable];

		NSMutableArray *values = [NSMutableArray array];

		void (^flushValues)() = ^{
			@synchronized (values) {
				[timerDisposable.disposable dispose];

				if (values.count == 0) return;

				RACTuple *tuple = [RACTuple tupleWithObjectsFromArray:values convertNullsToNils:NO];
				[values removeAllObjects];
				[subscriber sendNext:tuple];
			}
		};

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			@synchronized (values) {
				if (values.count == 0) {
					timerDisposable.disposable = [[[RACSignal
						interval:interval onScheduler:scheduler]
						take:1]
						subscribeNext:^(id _) {
							flushValues();
						}];
				}

				[values addObject:x];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			flushValues();
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -bufferWithTime: %f", self.name, (double)interval];
}

- (RACSignal *)collect {
	return [[self
		aggregateWithStartFactory:^{
			return [[NSMutableArray alloc] init];
		} reduce:^(NSMutableArray *collectedValues, id x) {
			[collectedValues addObject:(x ?: NSNull.null)];
			return collectedValues;
		}]
		setNameWithFormat:@"[%@] -collect", self.name];
}

- (RACSignal *)takeLast:(NSUInteger)count {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {		
		NSMutableArray *valuesTaken = [NSMutableArray arrayWithCapacity:count];

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[valuesTaken addObject:x ? : [RACTupleNil tupleNil]];
			
			while (valuesTaken.count > count) {
				[valuesTaken removeObjectAtIndex:0];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			for (id value in valuesTaken) {
				[subscriber sendNext:[value isKindOfClass:[RACTupleNil class]] ? nil : value];

				if (subscriber.disposable.disposed) return;
			}
			
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
}

- (RACSignal *)combineLatestWith:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		__block id lastSelfValue = nil;
		__block BOOL selfCompleted = NO;

		__block id lastOtherValue = nil;
		__block BOOL otherCompleted = NO;

		void (^sendNext)(void) = ^{
			@synchronized (subscriber) {
				if (lastSelfValue == nil || lastOtherValue == nil) return;
				[subscriber sendNext:[RACTuple tupleWithObjects:lastSelfValue, lastOtherValue, nil]];
			}
		};

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			@synchronized (subscriber) {
				lastSelfValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (subscriber) {
				selfCompleted = YES;
				if (otherCompleted) [subscriber sendCompleted];
			}
		}]];

		[subscriber.disposable addDisposable:[signal subscribeNext:^(id x) {
			@synchronized (subscriber) {
				lastOtherValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (subscriber) {
				otherCompleted = YES;
				if (selfCompleted) [subscriber sendCompleted];
			}
		}]];
	}] setNameWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
	return [[self join:signals block:^(RACSignal *left, RACSignal *right) {
		return [left combineLatestWith:right];
	}] setNameWithFormat:@"+combineLatest: %@", signals];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock {
	NSCParameterAssert(reduceBlock != nil);

	RACSignal *result = [self combineLatest:signals];

	// Although we assert this condition above, older versions of this method
	// supported this argument being nil. Avoid crashing Release builds of
	// apps that depended on that.
	if (reduceBlock != nil) result = [result reduceEach:reduceBlock];

	return [result setNameWithFormat:@"+combineLatest: %@ reduce:", signals];
}

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
	NSMutableArray *copiedSignals = [[NSMutableArray alloc] init];
	for (RACSignal *signal in signals) {
		[copiedSignals addObject:signal];
	}

	return [[copiedSignals.rac_signal flatten] setNameWithFormat:@"+merge: %@", copiedSignals];
}

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		NSMutableSet *activeSignals = [NSMutableSet setWithObject:self];
		NSMutableArray *queuedSignals = [NSMutableArray array];

		// Marks the given signal as completed.
		//
		// This block should only be accessed while synchronized on
		// `subscriber`.
		__block void (^completeSignal)(RACSignal *) = nil;

		// Returns whether the signal should complete.
		BOOL (^dequeueAndSubscribeIfAllowed)(void) = ^{
			RACSignal *signal;
			@synchronized (subscriber) {
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

			__block RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
				[subscriber.disposable removeDisposable:disposable];
			} completed:^{
				@synchronized (subscriber) {
					completeSignal(signal);
				}

				[subscriber.disposable removeDisposable:disposable];
			}];

			[subscriber.disposable addDisposable:disposable];
			return NO;
		};

		completeSignal = ^(RACSignal *signal) {
			[activeSignals removeObject:signal];

			BOOL completed = dequeueAndSubscribeIfAllowed();
			if (completed) {
				[subscriber sendCompleted];
			}
		};

		[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
			@synchronized (subscriber) {
				completeSignal = ^(RACSignal *signal) {
					// Do nothing. We're just replacing this block to break the
					// retain cycle.
				};
			}
		}]];

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			NSCAssert([x isKindOfClass:RACSignal.class], @"The source must be a signal of signals. Instead, got %@", x);

			RACSignal *innerSignal = x;
			@synchronized (subscriber) {
				[queuedSignals addObject:innerSignal];
			}

			dequeueAndSubscribeIfAllowed();
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (subscriber) {
				completeSignal(self);
			}
		}]];
	}] setNameWithFormat:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
}

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameWithFormat:@"[%@] -then:", self.name];
}

- (RACSignal *)concat {
	return [[self flatten:1] setNameWithFormat:@"[%@] -concat", self.name];
}

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock {
	NSCParameterAssert(startFactory != NULL);
	NSCParameterAssert(reduceBlock != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		__block id runningValue = startFactory();
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			runningValue = reduceBlock(runningValue, x);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:runningValue];
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -aggregateWithStartFactory:reduce:", self.name];
}

- (RACSignal *)aggregateWithStart:(id)start reduce:(id (^)(id running, id next))reduceBlock {
	RACSignal *signal = [self aggregateWithStartFactory:^{
		return start;
	} reduce:reduceBlock];

	return [signal setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduce:", self.name, [start rac_description]];
}

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
	return [self setKeyPath:keyPath onObject:object nilValue:nil];
}

- (RACDisposable *)setKeyPath:(NSString *)keyPath onObject:(NSObject *)object nilValue:(id)nilValue {
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(object != nil);

	keyPath = [keyPath copy];

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	// Purposely not retaining 'object', since we want to tear down the binding
	// when it deallocates normally.
	__block void * volatile objectPtr = (__bridge void *)object;

	RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
		NSObject *object = (__bridge id)objectPtr;
		[object setValue:x ?: nilValue forKeyPath:keyPath];
	} error:^(NSError *error) {
		NSObject *object = (__bridge id)objectPtr;

		NSCAssert(NO, @"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error from %@ in binding for key path \"%@\" on %@: %@", self, keyPath, object, error);

		[disposable dispose];
	} completed:^{
		[disposable dispose];
	}];

	[disposable addDisposable:subscriptionDisposable];

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
		NSCAssert(bindings[keyPath] == nil, @"Signal %@ is already bound to key path \"%@\" on object %@, adding signal %@ is undefined behavior", [bindings[keyPath] nonretainedObjectValue], keyPath, object, self);

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

	[object.rac_deallocDisposable addDisposable:disposable];
	
	RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
	return [RACDisposable disposableWithBlock:^{
		[objectDisposable removeDisposable:disposable];
		[disposable dispose];
	}];
}

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
	return [[RACSignal interval:interval onScheduler:scheduler withLeeway:0.0] setNameWithFormat:@"+interval: %f onScheduler: %@", (double)interval, scheduler];
}

+ (RACSignal *)interval:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler withLeeway:(NSTimeInterval)leeway {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *disposable = [scheduler after:[NSDate dateWithTimeIntervalSinceNow:interval] repeatingEvery:interval withLeeway:leeway schedule:^{
			[subscriber sendNext:[NSDate date]];
		}];

		[subscriber.disposable addDisposable:disposable];
	}] setNameWithFormat:@"+interval: %f onScheduler: %@ withLeeway: %f", (double)interval, scheduler, (double)leeway];
}

- (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[signalTrigger subscribeNext:^(id _) {
			[subscriber sendCompleted];
		} completed:^{
			[subscriber sendCompleted];
		}]];

		[self subscribe:subscriber];
	}] setNameWithFormat:@"[%@] -takeUntil: %@", self.name, signalTrigger];
}

- (RACSignal *)switchToLatest {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACSubject *signals = [RACSubject subject];

		[[signals
			flattenMap:^(RACSignal *x) {
				if (x == nil) return [RACSignal empty];

				NSCAssert([x isKindOfClass:RACSignal.class], @"-switchToLatest requires that the source signal (%@) send signals. Instead we got: %@", self, x);

				// -concat:[RACSignal never] prevents completion of the receiver from
				// prematurely terminating the inner signal.
				return [x takeUntil:[signals concat:[RACSignal never]]];
			}]
			subscribe:subscriber];

		[self subscribe:signals];
	}] setNameWithFormat:@"[%@] -switchToLatest", self.name];
}

+ (RACSignal *)switch:(RACSignal *)signal cases:(NSDictionary *)cases default:(RACSignal *)defaultSignal {
	NSCParameterAssert(signal != nil);
	NSCParameterAssert(cases != nil);

	for (id key in cases) {
		id value __attribute__((unused)) = cases[key];
		NSCAssert([value isKindOfClass:RACSignal.class], @"Expected all cases to be RACSignals, %@ isn't", value);
	}

	NSDictionary *copy = [cases copy];

	return [[[signal
		map:^(id key) {
			if (key == nil) key = RACTupleNil.tupleNil;

			RACSignal *signal = copy[key] ?: defaultSignal;
			if (signal == nil) {
				NSString *description = [NSString stringWithFormat:NSLocalizedString(@"No matching signal found for value %@", @""), key];
				return [RACSignal error:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorNoMatchingCase userInfo:@{ NSLocalizedDescriptionKey: description }]];
			}

			return signal;
		}]
		switchToLatest]
		setNameWithFormat:@"+switch: %@ cases: %@ default: %@", signal, cases, defaultSignal];
}

+ (RACSignal *)if:(RACSignal *)boolSignal then:(RACSignal *)trueSignal else:(RACSignal *)falseSignal {
	NSCParameterAssert(boolSignal != nil);
	NSCParameterAssert(trueSignal != nil);
	NSCParameterAssert(falseSignal != nil);

	return [[[boolSignal
		map:^(NSNumber *value) {
			NSCAssert([value isKindOfClass:NSNumber.class], @"Expected %@ to send BOOLs, not %@", boolSignal, value);
			
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

	[[self take:1] subscribeNext:^(id x) {
		[condition lock];

		value = x;
		localSuccess = YES;
		
		done = YES;
		[condition broadcast];
		[condition unlock];
	} error:^(NSError *e) {
		[condition lock];

		if (!done) {
			localSuccess = NO;
			localError = e;

			done = YES;
			[condition broadcast];
		}

		[condition unlock];
	} completed:^{
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
		ignoreValues]
		setNameWithFormat:@"[%@] -waitUntilCompleted:", self.name]
		firstOrDefault:nil success:&success error:error];
	
	return success;
}

- (NSArray *)array {
	return [[self collect] first];
}

+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

- (RACSignal *)shareWhileActive {
	// Although RACReplaySubject is deprecated for consumers, we're going to use it
	// internally for the foreseeable future. We just want to expose something
	// higher level.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"

	NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
	lock.name = @"com.github.ReactiveCocoa.shareWhileActive";

	// These should only be used while `lock` is held.
	__block NSUInteger subscriberCount = 0;
	__block RACDisposable *underlyingDisposable = nil;
	__block RACReplaySubject *inflightSubscription = nil;

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			[lock lock];
			@onExit {
				[lock unlock];
			};

			if (subscriberCount++ == 0) {
				// We're the first subscriber, so create the underlying
				// subscription.
				inflightSubscription = [RACReplaySubject subject];
				underlyingDisposable = [self subscribe:inflightSubscription];
			}

			[inflightSubscription subscribe:subscriber];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				[lock lock];
				@onExit {
					[lock unlock];
				};

				NSCAssert(subscriberCount > 0, @"Mismatched decrement of subscriberCount (%lu)", (unsigned long)subscriberCount);
				if (--subscriberCount == 0) {
					// We're the last subscriber, so dispose of the
					// underlying subscription.
					[underlyingDisposable dispose];
					underlyingDisposable = nil;
				}
			}]];
		}]
		setNameWithFormat:@"[%@] -shareWhileActive", self.name];

	#pragma clang diagnostic pop
}

- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *timeoutDisposable = [[[RACSignal
			interval:interval onScheduler:scheduler]
			take:1]
			subscribeNext:^(id _) {
				[subscriber sendError:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorTimedOut userInfo:nil]];
			}];

		[subscriber.disposable addDisposable:timeoutDisposable];
		[self subscribe:subscriber];
	}] setNameWithFormat:@"[%@] -timeout: %f", self.name, (double)interval];
}

- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *disposable = [self subscribeNext:^(id x) {
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

		[subscriber.disposable addDisposable:disposable];
	}] setNameWithFormat:@"[%@] -deliverOn: %@", self.name, scheduler];
}

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACDisposable *schedulingDisposable = [scheduler schedule:^{
			[self subscribe:subscriber];
		}];
		
		[subscriber.disposable addDisposable:schedulingDisposable];
	}] setNameWithFormat:@"[%@] -subscribeOn: %@", self.name, scheduler];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
	NSCParameterAssert(keyBlock != NULL);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		NSMutableDictionary *groups = [NSMutableDictionary dictionary];

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			id<NSCopying> key = keyBlock(x);
			RACGroupedSignal *groupSubject = nil;

			@synchronized (groups) {
				groupSubject = groups[key];
				if (groupSubject == nil) {
					groupSubject = [RACGroupedSignal signalWithKey:key];
					groups[key] = groupSubject;

					[subscriber sendNext:groupSubject];
				}
			}

			[groupSubject sendNext:(transformBlock != NULL ? transformBlock(x) : x)];
		} error:^(NSError *error) {
			[subscriber sendError:error];
			[groups.allValues makeObjectsPerformSelector:@selector(sendError:) withObject:error];
		} completed:^{
			[subscriber sendCompleted];
			[groups.allValues makeObjectsPerformSelector:@selector(sendCompleted)];
		}]];
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
	NSCParameterAssert(predicateBlock != NULL);
	
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
	NSCParameterAssert(predicateBlock != NULL);
	
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
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		__block NSInteger currentRetryCount = 0;
		RACDisposable *disposable = subscribeForever(self,
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

		[subscriber.disposable addDisposable:disposable];
	}] setNameWithFormat:@"[%@] -retry: %lu", self.name, (unsigned long)retryCount];
}

- (RACSignal *)retry {
	return [[self retry:0] setNameWithFormat:@"[%@] -retry", self.name];
}

- (RACSignal *)sample:(RACSignal *)sampler {
	NSCParameterAssert(sampler != nil);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		NSLock *lock = [[NSLock alloc] init];
		__block id lastValue;
		__block BOOL hasValue = NO;

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[lock lock];
			hasValue = YES;
			lastValue = x;
			[lock unlock];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];

		[subscriber.disposable addDisposable:[sampler subscribeNext:^(id _) {
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
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}]];
	}] setNameWithFormat:@"[%@] -sample: %@", self.name, sampler];
}

- (RACSignal *)ignoreValues {
	return [[self filter:^(id _) {
		return NO;
	}] setNameWithFormat:@"[%@] -ignoreValues", self.name];
}

- (RACSignal *)materialize {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
			[subscriber sendNext:[RACEvent eventWithValue:x]];
		} error:^(NSError *error) {
			[subscriber sendNext:[RACEvent eventWithError:error]];
			[subscriber sendCompleted];
		} completed:^{
			[subscriber sendNext:RACEvent.completedEvent];
			[subscriber sendCompleted];
		}]];
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
					return [RACSignal error:event.error];

				case RACEventTypeNext:
					return [RACSignal return:event.value];
			}
		};
	}] setNameWithFormat:@"[%@] -dematerialize", self.name];
}

- (RACSignal *)not {
	return [[self map:^(NSNumber *value) {
		NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);

		return @(!value.boolValue);
	}] setNameWithFormat:@"[%@] -not", self.name];
}

- (RACSignal *)and {
	return [[self map:^(RACTuple *tuple) {
		NSCAssert([tuple isKindOfClass:RACTuple.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
		NSCAssert(tuple.count > 0, @"-and must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");

		for (NSNumber *number in tuple) {
			NSCAssert([number isKindOfClass:NSNumber.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);
			
			if (!number.boolValue) return @NO;
		}

		return @YES;
	}] setNameWithFormat:@"[%@] -and", self.name];
}

- (RACSignal *)or {
	return [[self map:^(RACTuple *tuple) {
		NSCAssert([tuple isKindOfClass:RACTuple.class], @"-or must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
		NSCAssert(tuple.count > 0, @"-or must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");
		
		for (NSNumber *number in tuple) {
			NSCAssert([number isKindOfClass:NSNumber.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);

			if (number.boolValue) return @YES;
		}

		return @NO;
	}] setNameWithFormat:@"[%@] -or", self.name];
}

- (RACSignal *)bind:(RACSignalBindBlock (^)(void))block {
	NSCParameterAssert(block != NULL);

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

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		RACSignalBindBlock bindingBlock = block();
		NSMutableArray *signals = [NSMutableArray arrayWithObject:self];

		void (^completeSignal)(RACSignal *, RACDisposable *) = ^(RACSignal *signal, RACDisposable *finishedDisposable) {
			BOOL removeDisposable = NO;

			@synchronized (signals) {
				[signals removeObject:signal];

				if (signals.count == 0) {
					[subscriber sendCompleted];
				} else {
					removeDisposable = YES;
				}
			}

			if (removeDisposable) [subscriber.disposable removeDisposable:finishedDisposable];
		};

		void (^addSignal)(RACSignal *) = ^(RACSignal *signal) {
			@synchronized (signals) {
				[signals addObject:signal];
			}

			RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
			[subscriber.disposable addDisposable:selfDisposable];

			selfDisposable.disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(signal, selfDisposable);
				}
			}];
		};

		@autoreleasepool {
			RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
			[subscriber.disposable addDisposable:selfDisposable];

			selfDisposable.disposable = [self subscribeNext:^(id x) {
				BOOL stop = NO;
				id signal = bindingBlock(x, &stop);

				@autoreleasepool {
					if (signal != nil) addSignal(signal);
					if (signal == nil || stop) {
						[selfDisposable dispose];
						completeSignal(self, selfDisposable);
					}
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(self, selfDisposable);
				}
			}];
		}
	}] setNameWithFormat:@"[%@] -bind:", self.name];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation RACSignal (DeprecatedOperations)

- (RACSequence *)sequence {
	return [[RACSignalSequence sequenceWithSignal:self] setNameWithFormat:@"[%@] -sequence", self.name];
}

- (RACSignal *)initially:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal defer:^{
		block();
		return self;
	}] setNameWithFormat:@"[%@] -initially:", self.name];
}

- (RACSignal *)finally:(void (^)(void))block {
	return [self doFinished:block];
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
	RACMulticastConnection *connection = [self multicast:[RACReplaySubject subject]];
	return [[RACSignal
		defer:^{
			[connection connect];
			return connection.signal;
		}]
		setNameWithFormat:@"[%@] -replayLazily", self.name];
}

- (NSArray *)toArray {
	return [self array];
}

@end

#pragma clang diagnostic pop
