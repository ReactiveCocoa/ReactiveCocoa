//
//  RACSignal.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACDynamicSignal.h"
#import "RACEmptySignal.h"
#import "RACErrorSignal.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACReturnSignal.h"
#import "RACScheduler.h"
#import "RACSerialDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber+Private.h"
#import "RACTuple.h"
#import <libkern/OSAtomic.h>

@implementation RACSignal

#pragma mark Lifecycle

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	return [RACDynamicSignal createSignal:didSubscribe];
}

+ (RACSignal *)error:(NSError *)error {
	return [RACErrorSignal error:error];
}

+ (RACSignal *)never {
	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		return nil;
	}] setNameWithFormat:@"+never"];
}

+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != NULL);

	RACSignal *signal = [self startLazilyWithScheduler:scheduler block:block];
	// Subscribe to force the lazy signal to call its block.
	[[signal publish] connect];
	return [signal setNameWithFormat:@"+startEagerlyWithScheduler: %@ block:", scheduler];
}

+ (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != NULL);

	RACMulticastConnection *connection = [[RACSignal
		createSignal:^ id (id<RACSubscriber> subscriber) {
			block(subscriber);
			return nil;
		}]
		multicast:[RACReplaySubject subject]];
	
	return [[[RACSignal
		createSignal:^ id (id<RACSubscriber> subscriber) {
			[connection.signal subscribe:subscriber];
			[connection connect];
			return nil;
		}]
		subscribeOn:scheduler]
		setNameWithFormat:@"+startLazilyWithScheduler: %@ block:", scheduler];
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> name: %@", self.class, self, self.name];
}

@end

@implementation RACSignal (RACStream)

+ (RACSignal *)empty {
	return [RACEmptySignal empty];
}

+ (RACSignal *)return:(id)value {
	return [RACReturnSignal return:value];
}

- (RACSignal *)bind:(RACStreamBindBlock (^)(void))block {
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

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACStreamBindBlock bindingBlock = block();

		__block volatile int32_t signalCount = 1;   // indicates self

		RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

		void (^completeSignal)(RACDisposable *) = ^(RACDisposable *finishedDisposable) {
			if (OSAtomicDecrement32Barrier(&signalCount) == 0) {
				[subscriber sendCompleted];
				[compoundDisposable dispose];
			} else {
				[compoundDisposable removeDisposable:finishedDisposable];
			}
		};

		void (^addSignal)(RACSignal *) = ^(RACSignal *signal) {
			OSAtomicIncrement32Barrier(&signalCount);

			RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
			[compoundDisposable addDisposable:selfDisposable];

			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[compoundDisposable dispose];
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(selfDisposable);
				}
			}];

			selfDisposable.disposable = disposable;
		};

		@autoreleasepool {
			RACSerialDisposable *selfDisposable = [[RACSerialDisposable alloc] init];
			[compoundDisposable addDisposable:selfDisposable];

			RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
				// Manually check disposal to handle synchronous errors.
				if (compoundDisposable.disposed) return;

				BOOL stop = NO;
				id signal = bindingBlock(x, &stop);

				@autoreleasepool {
					if (signal != nil) addSignal(signal);
					if (signal == nil || stop) {
						[selfDisposable dispose];
						completeSignal(selfDisposable);
					}
				}
			} error:^(NSError *error) {
				[compoundDisposable dispose];
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(selfDisposable);
				}
			}];

			selfDisposable.disposable = bindingDisposable;
		}

		return compoundDisposable;
	}] setNameWithFormat:@"[%@] -bind:", self.name];
}

- (RACSignal *)concat:(RACSignal *)signal {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *compoundDisposable = [[RACCompoundDisposable alloc] init];

		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			RACDisposable *concattedDisposable = [signal subscribe:subscriber];
			[compoundDisposable addDisposable:concattedDisposable];
		}];

		[compoundDisposable addDisposable:sourceDisposable];
		return compoundDisposable;
	}] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

- (RACSignal *)zipWith:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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

				RACTuple *tuple = RACTuplePack(selfValues[0], otherValues[0]);
				[selfValues removeObjectAtIndex:0];
				[otherValues removeObjectAtIndex:0];

				[subscriber sendNext:tuple];
				sendCompletedIfNecessary();
			}
		};

		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
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

		RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
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

		return [RACDisposable disposableWithBlock:^{
			[selfDisposable dispose];
			[otherDisposable dispose];
		}];
	}] setNameWithFormat:@"[%@] -zipWith: %@", self.name, signal];
}

@end

@implementation RACSignal (Subscription)

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCAssert(NO, @"This method must be overridden by subclasses");
	return nil;
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	NSCParameterAssert(nextBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	NSCParameterAssert(nextBlock != NULL);
	NSCParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSCParameterAssert(nextBlock != NULL);
	NSCParameterAssert(errorBlock != NULL);
	NSCParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	NSCParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	NSCParameterAssert(completedBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:NULL completed:completedBlock];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	NSCParameterAssert(nextBlock != NULL);
	NSCParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:nextBlock error:errorBlock completed:NULL];
	return [self subscribe:o];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *))errorBlock completed:(void (^)(void))completedBlock {
	NSCParameterAssert(completedBlock != NULL);
	NSCParameterAssert(errorBlock != NULL);
	
	RACSubscriber *o = [RACSubscriber subscriberWithNext:NULL error:errorBlock completed:completedBlock];
	return [self subscribe:o];
}

@end

@implementation RACSignal (Debugging)

- (RACSignal *)logAll {
	return [[[self logNext] logError] logCompleted];
}

- (RACSignal *)logNext {
	return [[self doNext:^(id x) {
		NSLog(@"%@ next: %@", self, x);
	}] setNameWithFormat:@"%@", self.name];
}

- (RACSignal *)logError {
	return [[self doError:^(NSError *error) {
		NSLog(@"%@ error: %@", self, error);
	}] setNameWithFormat:@"%@", self.name];
}

- (RACSignal *)logCompleted {
	return [[self doCompleted:^{
		NSLog(@"%@ completed", self);
	}] setNameWithFormat:@"%@", self.name];
}

@end

@implementation RACSignal (Testing)

static const NSTimeInterval RACSignalAsynchronousWaitTimeout = 10;

- (id)asynchronousFirstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
	NSCAssert([NSThread isMainThread], @"%s should only be used from the main thread", __func__);

	__block id result = defaultValue;
	__block BOOL done = NO;

	// Ensures that we don't pass values across thread boundaries by reference.
	__block NSError *localError;
	__block BOOL localSuccess = YES;

	[[[[self
		take:1]
		timeout:RACSignalAsynchronousWaitTimeout onScheduler:[RACScheduler scheduler]]
		deliverOn:RACScheduler.mainThreadScheduler]
		subscribeNext:^(id x) {
			result = x;
			done = YES;
		} error:^(NSError *e) {
			if (!done) {
				localSuccess = NO;
				localError = e;
				done = YES;
			}
		} completed:^{
			done = YES;
		}];
	
	do {
		[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	} while (!done);

	if (success != NULL) *success = localSuccess;
	if (error != NULL) *error = localError;

	return result;
}

- (BOOL)asynchronouslyWaitUntilCompleted:(NSError **)error {
	BOOL success = NO;
	[[self ignoreValues] asynchronousFirstOrDefault:nil success:&success error:error];
	return success;
}

@end
