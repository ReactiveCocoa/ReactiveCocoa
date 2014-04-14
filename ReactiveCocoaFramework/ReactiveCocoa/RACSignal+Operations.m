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
#import "RACDynamicSignalGenerator.h"
#import "RACEvent.h"
#import "RACGroupedSignal.h"
#import "RACLiveSubscriber.h"
#import "RACMulticastConnection+Private.h"
#import "RACReplaySubject.h"
#import "RACScheduler+Private.h"
#import "RACScheduler.h"
#import "RACSerialDisposable.h"
#import "RACSignal+Private.h"
#import "RACSignalSequence.h"
#import "RACStream+Private.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

NSString * const RACSignalErrorDomain = @"RACSignalErrorDomain";

const NSInteger RACSignalErrorTimedOut = 1;
const NSInteger RACSignalErrorNoMatchingCase = 2;

@implementation RACSignal (Operations)

- (RACSignal *)concat:(RACSignal *)signal {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[self subscribeSavingDisposable:^(RACDisposable *disposable) {
			[subscriber.disposable addDisposable:disposable];
		} next:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[signal subscribe:subscriber];
		}];
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
	return [[RACSignal
		defer:^{
			__block NSUInteger skipped = 0;

			return [self transform:^(id<RACSubscriber> subscriber, id x) {
				if (skipped++ < skipCount) return;

				[subscriber sendNext:x];
			}];
		}]
		setNameWithFormat:@"[%@] -skip: %lu", self.name, (unsigned long)skipCount];
}

- (RACSignal *)take:(NSUInteger)takeCount {
	return [[RACSignal
		defer:^{
			__block NSUInteger taken = 0;

			return [self transform:^(id<RACSubscriber> subscriber, id x) {
				if (taken < takeCount) [subscriber sendNext:x];
				if (++taken >= takeCount) [subscriber sendCompleted];
			}];
		}]
		setNameWithFormat:@"[%@] -take: %lu", self.name, (unsigned long)takeCount];
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

		[self subscribeSavingDisposable:^(RACDisposable *disposable) {
			[subscriber.disposable addDisposable:disposable];
		} next:^(id x) {
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
		}];

		[signal subscribeSavingDisposable:^(RACDisposable *disposable) {
			[subscriber.disposable addDisposable:disposable];
		} next:^(id x) {
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
		}];
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
	NSCParameterAssert(block != nil);

	return [[RACSignal
		defer:^{
			__block id running = startingValue;

			return [self map:^(id x) {
				running = block(running, x);
				return running;
			}];
		}]
		setNameWithFormat:@"[%@] -scanWithStart: %@ reduce:", self.name, [startingValue rac_description]];
}

- (RACSignal *)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id current))reduceBlock {
	return [super combinePreviousWithStart:start reduce:reduceBlock];
}

- (RACSignal *)distinctUntilChanged {
	return [[RACSignal
		defer:^{
			__block id lastValue = [[NSObject alloc] init];

			return [self transform:^(id<RACSubscriber> subscriber, id x) {
				if (x == lastValue || [x isEqual:lastValue]) return;

				lastValue = x;
				[subscriber sendNext:x];
			}];
		}]
		setNameWithFormat:@"[%@] -distinctUntilChanged", self.name];
}

- (RACSignal *)takeWhile:(BOOL (^)(id x))predicateBlock {
	return [[self
		transform:^(id<RACSubscriber> subscriber, id x) {
			if (!predicateBlock(x)) return [subscriber sendCompleted];

			[subscriber sendNext:x];
		}]
		setNameWithFormat:@"[%@] -takeWhile:", self.name];
}

- (RACSignal *)skipWhile:(BOOL (^)(id x))predicateBlock {
	return [[RACSignal
		defer:^RACSignal *{
			__block BOOL skipping = YES;

			return [self transform:^(id<RACSubscriber> subscriber, id x) {
				skipping = skipping && predicateBlock(x);
				if (skipping) return;

				[subscriber sendNext:x];
			}];
		}]
		setNameWithFormat:@"[%@] -skipWhile:", self.name];
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

- (RACSignal *)throttleDiscardingEarliest:(NSTimeInterval)interval {
	NSCParameterAssert(interval >= 0);

	return [[[self
		map:^(id x) {
			return [[RACSignal return:x] delay:interval];
		}]
		flatten:1 withPolicy:RACSignalFlattenPolicyDisposeEarliest]
		setNameWithFormat:@"[%@] -throttleDiscardingEarliest: %f", self.name, (double)interval];
}

- (RACSignal *)throttleDiscardingLatest:(NSTimeInterval)interval {
	NSCParameterAssert(interval >= 0);

	return [[[self
		map:^(id x) {
			return [[RACSignal return:x] delay:interval];
		}]
		flatten:1 withPolicy:RACSignalFlattenPolicyDisposeLatest]
		setNameWithFormat:@"[%@] -throttleDiscardingLatest: %f", self.name, (double)interval];
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
	RACSignalGenerator *generator = [RACDynamicSignalGenerator generatorWithReflexiveBlock:^(RACSignal *signal, RACSignalGenerator *generator) {
		return [signal concat:[RACSignal defer:^{
			return [generator signalWithValue:signal];
		}]];
	}];

	return [[generator signalWithValue:self] setNameWithFormat:@"[%@] -repeat", self.name];
}

- (RACSignal *)catch:(RACSignal * (^)(NSError *error))catchBlock {
	NSCParameterAssert(catchBlock != NULL);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		[self subscribeSavingDisposable:^(RACDisposable *disposable) {
			[subscriber.disposable addDisposable:disposable];
		} next:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			RACSignal *signal = catchBlock(error);
			NSCAssert(signal != nil, @"Expected non-nil signal from catch block on %@", self);

			[signal subscribe:subscriber];
		} completed:^{
			[subscriber sendCompleted];
		}];
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

				RACTuple *tuple = [RACTuple tupleWithArray:values convertNullsToNils:NO];
				[values removeAllObjects];
				[subscriber sendNext:tuple];
			}
		};

		[subscriber.disposable addDisposable:[self subscribeNext:^(id x) {
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
		}]];
	}] setNameWithFormat:@"[%@] -bufferWithTime: %f", self.name, (double)interval];
}

- (RACSignal *)collect {
	return [[RACSignal
		defer:^{
			return [self aggregateWithStart:[NSMutableArray array] reduce:^(NSMutableArray *values, id x) {
				[values addObject:x ?: NSNull.null];
				return values;
			}];
		}]
		setNameWithFormat:@"[%@] -collect", self.name];
}

- (RACSignal *)takeLast:(NSUInteger)count {
	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {		
			NSMutableArray *valuesTaken = [[NSMutableArray alloc] initWithCapacity:count];

			[self subscribeSavingDisposable:^(RACDisposable *disposable) {
				[subscriber.disposable addDisposable:disposable];
			} next:^(id x) {
				[valuesTaken addObject:x ?: RACTupleNil.tupleNil];
				
				while (valuesTaken.count > count) {
					[valuesTaken removeObjectAtIndex:0];
				}
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				for (id value in valuesTaken) {
					[subscriber sendNext:(value == RACTupleNil.tupleNil ? nil : value)];

					if (subscriber.disposable.disposed) return;
				}
				
				[subscriber sendCompleted];
			}];
		}]
		setNameWithFormat:@"[%@] -takeLast: %lu", self.name, (unsigned long)count];
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

- (RACSignal *)flatten:(NSUInteger)maxConcurrent withPolicy:(RACSignalFlattenPolicy)policy {
	NSCParameterAssert(maxConcurrent > 0);

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
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

		// The signals waiting to be started. This only applies to the "wait"
		// policy.
		//
		// This array should only be used while synchronized on `subscriber`.
		NSMutableArray *queuedSignals = nil;
		if (policy == RACSignalFlattenPolicyQueue) queuedSignals = [NSMutableArray array];

		subscribeToSignal = ^(RACSignal *signal) {
			RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

			@synchronized (subscriber) {
				[subscriber.disposable addDisposable:serialDisposable];
				[activeDisposables addObject:serialDisposable];
			}

			serialDisposable.disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				RACSignal *nextSignal;

				@synchronized (subscriber) {
					[subscriber.disposable removeDisposable:serialDisposable];
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

		[subscriber.disposable addDisposable:[self subscribeNext:^(RACSignal *signal) {
			if (signal == nil) return;

			NSCAssert([signal isKindOfClass:RACSignal.class], @"Expected a RACSignal, got %@", signal);

			@synchronized (subscriber) {
				if (activeDisposables.count >= maxConcurrent) {
					switch (policy) {
						case RACSignalFlattenPolicyQueue: {
							[queuedSignals addObject:signal];

							// If we need to wait, skip subscribing to this
							// signal.
							return;
						}

						case RACSignalFlattenPolicyDisposeEarliest: {
							RACDisposable *disposable = activeDisposables[0];

							[activeDisposables removeObjectAtIndex:0];
							[subscriber.disposable removeDisposable:disposable];

							[disposable dispose];
							break;
						}

						case RACSignalFlattenPolicyDisposeLatest: {
							RACDisposable *disposable = activeDisposables.lastObject;

							[activeDisposables removeLastObject];
							[subscriber.disposable removeDisposable:disposable];

							[disposable dispose];
							break;
						}
					}
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
	}] setNameWithFormat:@"[%@] -flatten: %lu withPolicy: %u", self.name, (unsigned long)maxConcurrent, (unsigned)policy];
}

- (RACSignal *)concat {
	return [[self flatten:1 withPolicy:RACSignalFlattenPolicyQueue] setNameWithFormat:@"[%@] -concat", self.name];
}

- (RACSignal *)aggregateWithStart:(id)start reduce:(id (^)(id running, id next))reduceBlock {
	return [[[[self
		scanWithStart:start reduce:reduceBlock]
		startWith:start]
		takeLast:1]
		setNameWithFormat:@"[%@] -aggregateWithStart: %@ reduce:", self.name, [start rac_description]];
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

- (RACSignal *)takeUntilReplacement:(RACSignal *)replacement {
	return [RACSignal create:^(id<RACSubscriber> subscriber) {
		RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
		[subscriber.disposable addDisposable:selfDisposable];

		[subscriber.disposable addDisposable:[replacement subscribeNext:^(id x) {
			[selfDisposable dispose];
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[selfDisposable dispose];
			[subscriber sendError:error];
		} completed:^{
			[selfDisposable dispose];
			[subscriber sendCompleted];
		}]];

		if (!selfDisposable.disposed) {
			selfDisposable.disposable = [[self
				concat:[RACSignal never]]
				subscribe:subscriber];
		}
	}];
}

- (RACSignal *)switchToLatest {
	return [[self flatten:1 withPolicy:RACSignalFlattenPolicyDisposeEarliest] setNameWithFormat:@"[%@] -switchToLatest", self.name];
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
		RACDisposable *timeoutDisposable = [scheduler afterDelay:interval schedule:^{
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

- (RACSignal *)retry:(NSUInteger)retryCount {
	return [[RACSignal defer:^{
		RACSignalGenerator *generator = [RACDynamicSignalGenerator generatorWithReflexiveBlock:^(NSNumber *currentRetryCount, RACSignalGenerator *generator) {
			return [self catch:^(NSError *error) {
				if (retryCount == 0 || currentRetryCount.unsignedIntegerValue < retryCount) {
					return [generator signalWithValue:@(currentRetryCount.unsignedIntegerValue + 1)];
				} else {
					// We've retried enough times, so let the error propagate.
					return [RACSignal error:error];
				}
			}];
		}];

		return [generator signalWithValue:@0];
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
	return [[self
		transform:^(id<RACSubscriber> subscriber, RACEvent *event) {
			switch (event.eventType) {
				case RACEventTypeNext:
					return [subscriber sendNext:event.value];

				case RACEventTypeError:
					return [subscriber sendError:event.error];

				case RACEventTypeCompleted:
					return [subscriber sendCompleted];
			}
		}]
		setNameWithFormat:@"[%@] -dematerialize", self.name];
}

- (RACSignal *)not {
	return [[self map:^(NSNumber *value) {
		NSCAssert([value isKindOfClass:NSNumber.class], @"-not must only be used on a signal of NSNumbers. Instead, got: %@", value);

		return @(value.boolValue ? NO : YES);
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

- (RACSignal *)transform:(void (^)(id<RACSubscriber>, id))transformBlock {
	NSCParameterAssert(transformBlock != nil);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			[self subscribeSavingDisposable:^(RACDisposable *disposable) {
				[subscriber.disposable addDisposable:disposable];
			} next:^(id x) {
				transformBlock(subscriber, x);
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}];
		}]
		setNameWithFormat:@"[%@] -transform:", self.name];;
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

			RACSerialDisposable *innerDisposable = [[RACSerialDisposable alloc] init];
			[subscriber.disposable addDisposable:innerDisposable];

			[signal subscribeSavingDisposable:^(RACDisposable *disposable) {
				innerDisposable.disposable = disposable;
			} next:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(signal, innerDisposable);
				}
			}];
		};

		@autoreleasepool {
			RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
			[subscriber.disposable addDisposable:selfDisposable];

			[self subscribeSavingDisposable:^(RACDisposable *disposable) {
				selfDisposable.disposable = disposable;
			} next:^(id x) {
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

- (RACSignal *)throttle:(NSTimeInterval)interval {
	return [self throttleDiscardingEarliest:interval];
}

- (RACSignal *)throttle:(NSTimeInterval)interval valuesPassingTest:(BOOL (^)(id next))predicate {
	NSCParameterAssert(interval >= 0);
	NSCParameterAssert(predicate != nil);

	return [[[self
		map:^(id x) {
			RACSignal *signal = [RACSignal return:x];
			if (predicate(x)) {
				signal = [signal delay:interval];
			}

			return signal;
		}]
		flatten:1 withPolicy:RACSignalFlattenPolicyDisposeEarliest]
		setNameWithFormat:@"[%@] -throttle: %f valuesPassingTest:", self.name, (double)interval];
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

- (RACSignal *)flatten:(NSUInteger)maxConcurrent {
	if (maxConcurrent == 0) {
		return [self flatten];
	} else {
		return [self flatten:maxConcurrent withPolicy:RACSignalFlattenPolicyQueue];
	}
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

- (RACSignal *)aggregateWithStartFactory:(id (^)(void))startFactory reduce:(id (^)(id running, id next))reduceBlock {
	return [RACSignal defer:^{
		return [self aggregateWithStart:startFactory() reduce:reduceBlock];
	}];
}

- (RACSignal *)then:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	return [[[self
		ignoreValues]
		concat:[RACSignal defer:block]]
		setNameWithFormat:@"[%@] -then:", self.name];
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
