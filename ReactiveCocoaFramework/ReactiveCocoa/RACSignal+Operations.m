//
//  RACSignal+Operations.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-09-06.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal+Operations.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACCommand.h"
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

- (RACSignal *)doNext:(void (^)(id x))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			block(x);
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -doNext:", self.name];
	}];
}

- (RACSignal *)doError:(void (^)(NSError *error))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			block(error);
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -doError:", self.name];
	}];
}

- (RACSignal *)doCompleted:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			block();
			[subscriber sendCompleted];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -doCompleted:", self.name];
	}];
}

- (RACSignal *)throttle:(NSTimeInterval)interval {
	return [[self throttle:interval valuesPassingTest:^(id _) {
		return YES;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -throttle: %f", self.name, (double)interval];
	}];
}

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate {
	NSCParameterAssert(interval >= 0);
	NSCParameterAssert(predicate != nil);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		// Information about any currently-buffered `next` event.
		__block id nextValue = nil;
		__block BOOL hasNextValue = NO;
		RACSerialDisposable *nextDisposable = [[RACSerialDisposable alloc] init];

		void (^flushNext)(BOOL send) = ^(BOOL send) {
			@synchronized (compoundDisposable) {
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

			@synchronized (compoundDisposable) {
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
			[compoundDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			flushNext(YES);
			[subscriber sendCompleted];
		}];

		[compoundDisposable addDisposable:subscriptionDisposable];
		return compoundDisposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -throttle: %f valuesPassingTest:", self.name, (double)interval];
	}];
}

- (RACSignal *)delay:(NSTimeInterval)interval {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		// We may never use this scheduler, but we need to set it up ahead of
		// time so that our scheduled blocks are run serially if we do.
		RACScheduler *scheduler = [RACScheduler scheduler];

		void (^schedule)(dispatch_block_t) = ^(dispatch_block_t block) {
			RACScheduler *delayScheduler = RACScheduler.currentScheduler ?: scheduler;
			RACDisposable *schedulerDisposable = [delayScheduler afterDelay:interval schedule:block];
			[disposable addDisposable:schedulerDisposable];
		};

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			schedule(^{
				[subscriber sendNext:x];
			});
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			schedule(^{
				[subscriber sendCompleted];
			});
		}];

		[disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -delay: %f", self.name, (double)interval];
	}];
}

- (RACSignal *)repeat {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -repeat", self.name];
	}];
}

- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
	NSCParameterAssert(catchBlock != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *catchDisposable = [[RACSerialDisposable alloc] init];

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			RACSignal *signal = catchBlock(error);
			NSCAssert(signal != nil, @"Expected non-nil signal from catch block on %@", self);
			catchDisposable.disposable = [signal subscribe:subscriber];
		} completed:^{
			[subscriber sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[catchDisposable dispose];
			[subscriptionDisposable dispose];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -catch:", self.name];
	}];
}

- (RACSignal *)catchTo:(RACSignal *)signal {
	return [[self catch:^(NSError *error) {
		return signal;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -catchTo: %@", self.name, signal];
	}];
}

- (RACSignal *)try:(BOOL (^)(id value, NSError **errorPtr))tryBlock {
	NSCParameterAssert(tryBlock != NULL);
	
	return [[self flattenMap:^(id value) {
		NSError *error = nil;
		BOOL passed = tryBlock(value, &error);
		return (passed ? [RACSignal return:value] : [RACSignal error:error]);
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -try:", self.name];
	}];
}

- (RACSignal *)tryMap:(id (^)(id value, NSError **errorPtr))mapBlock {
	NSCParameterAssert(mapBlock != NULL);
	
	return [[self flattenMap:^(id value) {
		NSError *error = nil;
		id mappedValue = mapBlock(value, &error);
		return (mappedValue == nil ? [RACSignal error:error] : [RACSignal return:mappedValue]);
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -tryMap:", self.name];
	}];
}

- (RACSignal *)initially:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[RACSignal defer:^{
		block();
		return self;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -initially:", self.name];
	}];
}

- (RACSignal *)finally:(void (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[[self
		doError:^(NSError *error) {
			block();
		}]
		doCompleted:^{
			block();
		}]
		setNameBlock:^{
			return [NSString stringWithFormat:@"[%@] -finally:", self.name];
		}];
}

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *timerDisposable = [[RACSerialDisposable alloc] init];
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

		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			@synchronized (values) {
				if (values.count == 0) {
					timerDisposable.disposable = [scheduler afterDelay:interval schedule:flushValues];
				}

				[values addObject:x ?: RACTupleNil.tupleNil];
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			flushValues();
			[subscriber sendCompleted];
		}];

		return [RACDisposable disposableWithBlock:^{
			[selfDisposable dispose];
			[timerDisposable dispose];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -bufferWithTime: %f", self.name, (double)interval];
	}];
}

- (RACSignal *)collect {
	return [[self aggregateWithStartFactory:^{
		return [[NSMutableArray alloc] init];
	} reduce:^(NSMutableArray *collectedValues, id x) {
		[collectedValues addObject:(x ?: NSNull.null)];
		return collectedValues;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -collect", self.name];
	}];
}

- (RACSignal *)takeLast:(NSUInteger)count {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {		
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
	}];
}

- (RACSignal *)combineLatestWith:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		__block id lastSelfValue = nil;
		__block BOOL selfCompleted = NO;

		__block id lastOtherValue = nil;
		__block BOOL otherCompleted = NO;

		void (^sendNext)(void) = ^{
			@synchronized (disposable) {
				if (lastSelfValue == nil || lastOtherValue == nil) return;
				[subscriber sendNext:[RACTuple tupleWithObjects:lastSelfValue, lastOtherValue, nil]];
			}
		};

		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			@synchronized (disposable) {
				lastSelfValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (disposable) {
				selfCompleted = YES;
				if (otherCompleted) [subscriber sendCompleted];
			}
		}];

		[disposable addDisposable:selfDisposable];

		RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
			@synchronized (disposable) {
				lastOtherValue = x ?: RACTupleNil.tupleNil;
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (disposable) {
				otherCompleted = YES;
				if (selfCompleted) [subscriber sendCompleted];
			}
		}];

		[disposable addDisposable:otherDisposable];

		return disposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -combineLatestWith: %@", self.name, signal];
	}];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals {
	return [[self join:signals block:^(RACSignal *left, RACSignal *right) {
		return [left combineLatestWith:right];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"+combineLatest: %@", signals];
	}];
}

+ (RACSignal *)combineLatest:(id<NSFastEnumeration>)signals reduce:(id (^)())reduceBlock {
	NSCParameterAssert(reduceBlock != nil);

	RACSignal *result = [self combineLatest:signals];

	// Although we assert this condition above, older versions of this method
	// supported this argument being nil. Avoid crashing Release builds of
	// apps that depended on that.
	if (reduceBlock != nil) result = [result reduceEach:reduceBlock];

	return [result setNameBlock:^{
		return [NSString stringWithFormat:@"+combineLatest: %@ reduce:", signals];
	}];
}

+ (RACSignal *)merge:(id<NSFastEnumeration>)signals {
	NSMutableArray *copiedSignals = [[NSMutableArray alloc] init];
	for (RACSignal *signal in signals) {
		[copiedSignals addObject:signal];
	}

	return [[[RACSignal
		createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			for (RACSignal *signal in copiedSignals) {
				[subscriber sendNext:signal];
			}

			[subscriber sendCompleted];
			return nil;
		}]
		flatten]
		setNameBlock:^{
			return [NSString stringWithFormat:@"+merge: %@", copiedSignals];
		}];
}

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *compoundDisposable = [[RACCompoundDisposable alloc] init];

		// Contains disposables for the currently active subscriptions.
		//
		// This should only be used while synchronized on `subscriber`.
		NSMutableArray *activeDisposables = [[NSMutableArray alloc] initWithCapacity:maxConcurrent];

		// Whether the signal-of-signals has completed yet.
		//
		// This should only be used while synchronized on `subscriber`.
		__block BOOL selfCompleted = NO;

		// Subscribes to the given signal.
		//
		// This will be set to nil once all signals have completed (to break
		// a retain cycle in the recursive block).
		__block void (^subscribeToSignal)(RACSignal *);

		// Sends completed to the subscriber if all signals are finished.
		//
		// This should only be used while synchronized on `subscriber`.
		void (^completeIfAllowed)(void) = ^{
			if (selfCompleted && activeDisposables.count == 0) {
				[subscriber sendCompleted];
				subscribeToSignal = nil;
			}
		};

		// The signals waiting to be started.
		//
		// This array should only be used while synchronized on `subscriber`.
		NSMutableArray *queuedSignals = [NSMutableArray array];

		subscribeToSignal = ^(RACSignal *signal) {
			RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

			@synchronized (subscriber) {
				[compoundDisposable addDisposable:serialDisposable];
				[activeDisposables addObject:serialDisposable];
			}

			serialDisposable.disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				RACSignal *nextSignal;

				@synchronized (subscriber) {
					[compoundDisposable removeDisposable:serialDisposable];
					[activeDisposables removeObjectIdenticalTo:serialDisposable];

					if (queuedSignals.count == 0) {
						completeIfAllowed();
						return;
					}

					nextSignal = queuedSignals[0];
					[queuedSignals removeObjectAtIndex:0];
				}

				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Warc-retain-cycles"
				// This retain cycle is broken in `completeIfAllowed`.
				subscribeToSignal(nextSignal);
				#pragma clang diagnostic pop
			}];
		};

		[compoundDisposable addDisposable:[self subscribeNext:^(RACSignal *signal) {
			if (signal == nil) return;

			NSCAssert([signal isKindOfClass:RACSignal.class], @"Expected a RACSignal, got %@", signal);

			@synchronized (subscriber) {
				if (maxConcurrent > 0 && activeDisposables.count >= maxConcurrent) {
					[queuedSignals addObject:signal];

					// If we need to wait, skip subscribing to this
					// signal.
					return;
				}
			}

			subscribeToSignal(signal);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (subscriber) {
				selfCompleted = YES;
				completeIfAllowed();
			}
		}]];

		return compoundDisposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -flatten: %lu", self.name, (unsigned long)maxConcurrent];
	}];
}

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameBlock:^{
			return [NSString stringWithFormat:@"[%@] -then:", self.name];
		}];
}

- (RACSignal *)concat {
	return [[self flatten:1] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -concat", self.name];
	}];
}

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock {
	NSCParameterAssert(startFactory != NULL);
	NSCParameterAssert(reduceBlock != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block id runningValue = startFactory();
		return [self subscribeNext:^(id x) {
			runningValue = reduceBlock(runningValue, x);
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendNext:runningValue];
			[subscriber sendCompleted];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -aggregateWithStartFactory:reduce:", self.name];
	}];
}

- (RACSignal *)aggregateWithStart:(id)start reduce:(id (^)(id running, id next))reduceBlock {
	RACSignal *signal = [self aggregateWithStartFactory:^{
		return start;
	} reduce:reduceBlock];

	return [signal setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -aggregateWithStart: %@ reduce:", self.name, start];
	}];
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

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [scheduler after:[NSDate dateWithTimeIntervalSinceNow:interval] repeatingEvery:interval withLeeway:leeway schedule:^{
			[subscriber sendNext:[NSDate date]];
		}];
	}] setNameWithFormat:@"+interval: %f onScheduler: %@ withLeeway: %f", (double)interval, scheduler, (double)leeway];
}

- (RACSignal *)takeUntil:(RACSignal *)signalTrigger {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
		void (^triggerCompletion)(void) = ^{
			[disposable dispose];
			[subscriber sendCompleted];
		};

		RACDisposable *triggerDisposable = [signalTrigger subscribeNext:^(id _) {
			triggerCompletion();
		} completed:^{
			triggerCompletion();
		}];

		[disposable addDisposable:triggerDisposable];

		if (!disposable.disposed) {
			RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[disposable dispose];
				[subscriber sendCompleted];
			}];

			[disposable addDisposable:selfDisposable];
		}

		return disposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -takeUntil: %@", self.name, signalTrigger];
	}];
}

- (RACSignal *)takeUntilReplacement:(RACSignal *)replacement {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];

		RACDisposable *replacementDisposable = [replacement subscribeNext:^(id x) {
			[selfDisposable dispose];
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[selfDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			[selfDisposable dispose];
			[subscriber sendCompleted];
		}];

		if (!selfDisposable.disposed) {
			selfDisposable.disposable = [[self
				concat:[RACSignal never]]
				subscribe:subscriber];
		}

		return [RACDisposable disposableWithBlock:^{
			[selfDisposable dispose];
			[replacementDisposable dispose];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -takeUntilReplacement: %@", self.name, replacement];
	}];
}

- (RACSignal *)switchToLatest {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACMulticastConnection *connection = [self publish];

		RACDisposable *subscriptionDisposable = [[connection.signal
			flattenMap:^(RACSignal *x) {
				NSCAssert(x == nil || [x isKindOfClass:RACSignal.class], @"-switchToLatest requires that the source signal (%@) send signals. Instead we got: %@", self, x);

				// -concat:[RACSignal never] prevents completion of the receiver from
				// prematurely terminating the inner signal.
				return [x takeUntil:[connection.signal concat:[RACSignal never]]];
			}]
			subscribe:subscriber];

		RACDisposable *connectionDisposable = [connection connect];
		return [RACDisposable disposableWithBlock:^{
			[subscriptionDisposable dispose];
			[connectionDisposable dispose];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -switchToLatest", self.name];
	}];
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
		setNameBlock:^{
			return [NSString stringWithFormat:@"+switch: %@ cases: %@ default: %@", signal, cases, defaultSignal];
		}];
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
		setNameBlock:^{
			return [NSString stringWithFormat:@"+if: %@ then: %@ else: %@", boolSignal, trueSignal, falseSignal];
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
		setNameBlock:^{
			return [NSString stringWithFormat:@"[%@] -waitUntilCompleted:", self.name];
		}]
		firstOrDefault:nil success:&success error:error];
	
	return success;
}

+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [block() subscribe:subscriber];
	}] setNameWithFormat:@"+defer:"];
}

- (NSArray *)toArray {
	return [[[self collect] first] copy];
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
	RACMulticastConnection *connection = [self multicast:[RACReplaySubject subject]];
	return [[RACSignal
		defer:^{
			[connection connect];
			return connection.signal;
		}]
		setNameWithFormat:@"[%@] -replayLazily", self.name];
}

- (RACSignal *)timeout:(NSTimeInterval)interval onScheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(scheduler != RACScheduler.immediateScheduler);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *timeoutDisposable = [scheduler afterDelay:interval schedule:^{
			[disposable dispose];
			[subscriber sendError:[NSError errorWithDomain:RACSignalErrorDomain code:RACSignalErrorTimedOut userInfo:nil]];
		}];

		[disposable addDisposable:timeoutDisposable];

		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[disposable dispose];
			[subscriber sendError:error];
		} completed:^{
			[disposable dispose];
			[subscriber sendCompleted];
		}];

		[disposable addDisposable:subscriptionDisposable];
		return disposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -timeout: %f", self.name, (double)interval];
	}];
}

- (RACSignal *)deliverOn:(RACScheduler *)scheduler {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -deliverOn: %@", self.name, scheduler];
	}];
}

- (RACSignal *)subscribeOn:(RACScheduler *)scheduler {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *schedulingDisposable = [scheduler schedule:^{
			RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];

			[disposable addDisposable:subscriptionDisposable];
		}];
		
		[disposable addDisposable:schedulingDisposable];
		return disposable;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -subscribeOn: %@", self.name, scheduler];
	}];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock transform:(id (^)(id object))transformBlock {
	NSCParameterAssert(keyBlock != NULL);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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

			[groups.allValues makeObjectsPerformSelector:@selector(sendError:) withObject:error];
		} completed:^{
			[subscriber sendCompleted];

			[groups.allValues makeObjectsPerformSelector:@selector(sendCompleted)];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -groupBy:transform:", self.name];
	}];
}

- (RACSignal *)groupBy:(id<NSCopying> (^)(id object))keyBlock {
	return [[self groupBy:keyBlock transform:nil] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -groupBy:", self.name];
	}];
}

- (RACSignal *)any {	
	return [[self any:^(id x) {
		return YES;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -any", self.name];
	}];
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -any:", self.name];
	}];
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -all:", self.name];
	}];
}

- (RACSignal *)retry:(NSInteger)retryCount {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -retry: %lu", self.name, (unsigned long)retryCount];
	}];
}

- (RACSignal *)retry {
	return [[self retry:0] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -retry", self.name];
	}];
}

- (RACSignal *)sample:(RACSignal *)sampler {
	NSCParameterAssert(sampler != nil);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSLock *lock = [[NSLock alloc] init];
		__block id lastValue;
		__block BOOL hasValue = NO;

		RACSerialDisposable *samplerDisposable = [[RACSerialDisposable alloc] init];
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

		samplerDisposable.disposable = [sampler subscribeNext:^(id _) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -sample: %@", self.name, sampler];
	}];
}

- (RACSignal *)ignoreValues {
	return [[self filter:^(id _) {
		return NO;
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -ignoreValues", self.name];
	}];
}

- (RACSignal *)materialize {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:[RACEvent eventWithValue:x]];
		} error:^(NSError *error) {
			[subscriber sendNext:[RACEvent eventWithError:error]];
			[subscriber sendCompleted];
		} completed:^{
			[subscriber sendNext:RACEvent.completedEvent];
			[subscriber sendCompleted];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -materialize", self.name];
	}];
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -dematerialize", self.name];
	}];
}

- (RACSignal *)not {
	return [[self map:^(NSNumber *value) {
		NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);

		return @(!value.boolValue);
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -not", self.name];
	}];
}

- (RACSignal *)and {
	return [[self map:^(RACTuple *tuple) {
		NSCAssert([tuple isKindOfClass:RACTuple.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
		NSCAssert(tuple.count > 0, @"-and must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");
		
		return @([tuple.rac_sequence all:^(NSNumber *number) {
			NSCAssert([number isKindOfClass:NSNumber.class], @"-and must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);
			
			return number.boolValue;
		}]);
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -and", self.name];
	}];
}

- (RACSignal *)or {
	return [[self map:^(RACTuple *tuple) {
		NSCAssert([tuple isKindOfClass:RACTuple.class], @"-or must only be used on a signal of RACTuples of NSNumbers. Instead, received: %@", tuple);
		NSCAssert(tuple.count > 0, @"-or must only be used on a signal of RACTuples of NSNumbers, with at least 1 value in the tuple");
		
		return @([tuple.rac_sequence any:^(NSNumber *number) {
			NSCAssert([number isKindOfClass:NSNumber.class], @"-or must only be used on a signal of RACTuples of NSNumbers. Instead, tuple contains a non-NSNumber value: %@", tuple);
			
			return number.boolValue;
		}]);
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -or", self.name];
	}];
}

@end

@implementation RACSignal (OperationsDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (RACSignal *)windowWithStart:(RACSignal *)openSignal close:(RACSignal * (^)(RACSignal *start))closeBlock {
	NSCParameterAssert(openSignal != nil);
	NSCParameterAssert(closeBlock != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -windowWithStart: %@ close:", self.name, openSignal];
	}];
}

- (RACSignal *)buffer:(NSUInteger)bufferCount {
	NSCParameterAssert(bufferCount > 0);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:bufferCount];
		RACSubject *windowCloseSubject = [RACSubject subject];
		
		RACDisposable *closeDisposable = [windowCloseSubject subscribeNext:^(id x) {
			[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:values convertNullsToNils:NO]];
			[values removeAllObjects];
		}];

		__block RACDisposable *innerDisposable = nil;
		RACDisposable *outerDisposable = [[self windowWithStart:self close:^(RACSignal *start) {
			return windowCloseSubject;
		}] subscribeNext:^(id x) {		
			innerDisposable = [x subscribeNext:^(id x) {
				[values addObject:x ? : [RACTupleNil tupleNil]];
				if(values.count % bufferCount == 0) {
					[windowCloseSubject sendNext:[RACUnit defaultUnit]];
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
			[closeDisposable dispose];
		}];
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -buffer: %lu", self.name, (unsigned long)bufferCount];
	}];
}

- (RACSignal *)let:(RACSignal * (^)(RACSignal *sharedSignal))letBlock {
	NSCParameterAssert(letBlock != NULL);
	
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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
	}] setNameBlock:^{
		return [NSString stringWithFormat:@"[%@] -let:", self.name];
	}];
}

+ (RACSignal *)interval:(NSTimeInterval)interval {
	return [RACSignal interval:interval onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityHigh]];
}

+ (RACSignal *)interval:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway {
	return [RACSignal interval:interval onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityHigh] withLeeway:leeway];
}

- (RACSignal *)timeout:(NSTimeInterval)interval {
	return [self timeout:interval onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityHigh]];
}

- (RACSignal *)bufferWithTime:(NSTimeInterval)interval {
	return [self bufferWithTime:interval onScheduler:[RACScheduler schedulerWithPriority:RACSchedulerPriorityHigh]];
}

- (RACDisposable *)toProperty:(NSString *)keyPath onObject:(NSObject *)object {
	return [self setKeyPath:keyPath onObject:object];
}

- (RACSignal *)ignoreElements {
	return [self ignoreValues];
}

- (RACSignal *)sequenceNext:(RACSignal * (^)(void))block {
	return [self then:block];
}

- (RACSignal *)aggregateWithStart:(id)start combine:(id (^)(id running, id next))combineBlock {
	return [self aggregateWithStart:start reduce:combineBlock];
}

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory combine:(id (^)(id running, id next))combineBlock {
	return [self aggregateWithStartFactory:startFactory reduce:combineBlock];
}

- (RACDisposable *)executeCommand:(RACCommand *)command {
	NSCParameterAssert(command != nil);

	return [self subscribeNext:^(id x) {
		[command execute:x];
	}];
}

#pragma clang diagnostic pop

@end
