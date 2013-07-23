//
//  RACSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "NSObject+RACDescription.h"
#import "EXTScope.h"
#import "RACBehaviorSubject.h"
#import "RACBlockTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACPassthroughSubscriber.h"
#import "RACReplaySubject.h"
#import "RACScheduler+Private.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACMulticastConnection.h"
#import <libkern/OSAtomic.h>

// Retains signals while they wait for subscriptions.
//
// This set must only be used on the main thread.
static NSMutableSet *RACActiveSignals = nil;

// A linked list of RACSignals, used in RACActiveSignalsToCheck.
typedef struct RACSignalList {
	CFTypeRef retainedSignal;
	struct RACSignalList *next;
} RACSignalList;

// An atomic queue of signals to check for subscribers. If any signals with zero
// subscribers are found in this queue, they are removed from RACActiveSignals.
static OSQueueHead RACActiveSignalsToCheck = OS_ATOMIC_QUEUE_INIT;

// Whether RACActiveSignalsToCheck will be enumerated on the next iteration on
// the main run loop.
static volatile uint32_t RACWillCheckActiveSignals = 0;

@interface RACSignal () {
	// Contains all subscribers to the receiver.
	//
	// All access to this array must be synchronized using `_subscribersLock`.
	NSMutableArray *_subscribers;

	// Synchronizes access to `_subscribers`.
	OSSpinLock _subscribersLock;
}

@property (nonatomic, copy) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);

@end

@implementation RACSignal

#pragma mark Lifecycle

+ (void)initialize {
	if (self != RACSignal.class) return;

	RACActiveSignals = [[NSMutableSet alloc] init];
}

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSignal *signal = [[RACSignal alloc] init];
	signal.didSubscribe = didSubscribe;
	return [signal setNameWithFormat:@"+createSignal:"];
}

+ (RACSignal *)error:(NSError *)error {
	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
		return nil;
	}] setNameWithFormat:@"+error: %@", error];
}

+ (RACSignal *)never {
	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		return nil;
	}] setNameWithFormat:@"+never"];
}

+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block {
	return [[self startWithScheduler:[RACScheduler scheduler] block:block] setNameWithFormat:@"+start:"];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block {
	return [[self startWithScheduler:scheduler subjectBlock:^(RACSubject *subject) {
		BOOL success = YES;
		NSError *error = nil;
		id returned = block(&success, &error);
		
		if (!success) {
			[subject sendError:error];
		} else {
			[subject sendNext:returned];
			[subject sendCompleted];
		}
	}] setNameWithFormat:@"+startWithScheduler:block:"];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block {
	NSCParameterAssert(block != NULL);

	RACReplaySubject *subject = [[RACReplaySubject subject] setNameWithFormat:@"+startWithScheduler:subjectBlock:"];

	[scheduler schedule:^{
		block(subject);
	}];
	
	return subject;
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
		setNameWithFormat:@"+startLazilyWithScheduler:%@ block:", scheduler];
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	
	// As soon as we're created we're already trying to be released. Such is life.
	[self invalidateGlobalRefIfNoNewSubscribersShowUp];
	
	return self;
}

static void RACCheckActiveSignals(void) {
	// Clear this flag now, so another thread can re-dispatch to the main queue
	// as needed.
	OSAtomicAnd32Barrier(0, &RACWillCheckActiveSignals);

	RACSignalList *elem;

	while ((elem = OSAtomicDequeue(&RACActiveSignalsToCheck, offsetof(RACSignalList, next))) != NULL) {
		RACSignal *signal = CFBridgingRelease(elem->retainedSignal);
		free(elem);

		if (signal.subscriberCount > 0) {
			// We want to keep the signal around until all its subscribers are done
			[RACActiveSignals addObject:signal];
		} else {
			[RACActiveSignals removeObject:signal];
		}
	}
}

- (void)invalidateGlobalRefIfNoNewSubscribersShowUp {
	// If no one subscribes in one pass of the main run loop, then we're free to
	// go. It's up to the caller to keep us alive if they still want us.
	RACSignalList *elem = malloc(sizeof(*elem));
	// This also serves to retain the signal until the next pass.
	elem->retainedSignal = CFBridgingRetain(self);
	OSAtomicEnqueue(&RACActiveSignalsToCheck, elem, offsetof(RACSignalList, next));

	// Not using a barrier because duplicate scheduling isn't erroneous, just
	// less optimized.
	int32_t willCheck = OSAtomicOr32Orig(1, &RACWillCheckActiveSignals);

	// Only schedule a check if RACWillCheckActiveSignals was 0 before.
	if (willCheck == 0) {
		dispatch_async(dispatch_get_main_queue(), ^{
			RACCheckActiveSignals();
		});
	}
}

#pragma mark Managing Subscribers

- (NSUInteger)subscriberCount {
	OSSpinLockLock(&_subscribersLock);
	NSUInteger count = _subscribers.count;
	OSSpinLockUnlock(&_subscribersLock);

	return count;
}

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(block != NULL);

	NSArray *currentSubscribers = nil;
	OSSpinLockLock(&_subscribersLock);
	currentSubscribers = [_subscribers copy];
	OSSpinLockUnlock(&_subscribersLock);
	
	for (id<RACSubscriber> subscriber in currentSubscribers) {
		block(subscriber);
	}
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> name: %@", self.class, self, self.name];
}

@end

@implementation RACSignal (RACStream)

+ (RACSignal *)empty {
	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
		return nil;
	}] setNameWithFormat:@"+empty"];
}

+ (RACSignal *)return:(id)value {
	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
		return nil;
	}] setNameWithFormat:@"+return: %@", [value rac_description]];
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

		NSMutableArray *signals = [NSMutableArray arrayWithObject:self];

		RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];

		void (^completeSignal)(RACSignal *, RACDisposable *) = ^(RACSignal *signal, RACDisposable *finishedDisposable) {
			BOOL removeDisposable = NO;

			@synchronized (signals) {
				[signals removeObject:signal];

				if (signals.count == 0) {
					[subscriber sendCompleted];
					[compoundDisposable dispose];
				} else {
					removeDisposable = YES;
				}
			}

			if (removeDisposable) [compoundDisposable removeDisposable:finishedDisposable];
		};

		void (^addSignal)(RACSignal *) = ^(RACSignal *signal) {
			@synchronized (signals) {
				[signals addObject:signal];
			}

			RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
			[compoundDisposable addDisposable:selfDisposable];

			__weak RACDisposable *weakSelfDisposable = selfDisposable;

			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				[compoundDisposable dispose];
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(signal, weakSelfDisposable);
				}
			}];

			if (disposable != nil) [selfDisposable addDisposable:disposable];
		};

		@autoreleasepool {
			RACCompoundDisposable *selfDisposable = [RACCompoundDisposable compoundDisposable];
			[compoundDisposable addDisposable:selfDisposable];

			__weak RACDisposable *weakSelfDisposable = selfDisposable;

			RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
				BOOL stop = NO;
				id signal = bindingBlock(x, &stop);

				@autoreleasepool {
					if (signal != nil) addSignal(signal);
					if (signal == nil || stop) completeSignal(self, weakSelfDisposable);
				}
			} error:^(NSError *error) {
				[compoundDisposable dispose];
				[subscriber sendError:error];
			} completed:^{
				@autoreleasepool {
					completeSignal(self, weakSelfDisposable);
				}
			}];

			if (bindingDisposable != nil) [selfDisposable addDisposable:bindingDisposable];
		}

		return compoundDisposable;
	}] setNameWithFormat:@"[%@] -bind:", self.name];
}

- (RACSignal *)concat:(RACSignal *)signal {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			RACDisposable *concattedDisposable = [signal subscribe:subscriber];
			if (concattedDisposable != nil) [disposable addDisposable:concattedDisposable];
		}];

		if (sourceDisposable != nil) [disposable addDisposable:sourceDisposable];
		return disposable;
	}] setNameWithFormat:@"[%@] -concat: %@", self.name, signal];
}

- (RACSignal *)zipWith:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

		__block BOOL selfCompleted = NO;
		NSMutableArray *selfValues = [NSMutableArray array];

		__block BOOL otherCompleted = NO;
		NSMutableArray *otherValues = [NSMutableArray array];

		void (^sendCompletedIfNecessary)(void) = ^{
			@synchronized (disposable) {
				BOOL selfEmpty = (selfCompleted && selfValues.count == 0);
				BOOL otherEmpty = (otherCompleted && otherValues.count == 0);
				if (selfEmpty || otherEmpty) [subscriber sendCompleted];
			}
		};

		void (^sendNext)(void) = ^{
			@synchronized (disposable) {
				if (selfValues.count == 0) return;
				if (otherValues.count == 0) return;

				RACTuple *tuple = [RACTuple tupleWithObjects:selfValues[0], otherValues[0], nil];
				[selfValues removeObjectAtIndex:0];
				[otherValues removeObjectAtIndex:0];

				[subscriber sendNext:tuple];
				sendCompletedIfNecessary();
			}
		};

		RACDisposable *selfDisposable = [self subscribeNext:^(id x) {
			@synchronized (disposable) {
				[selfValues addObject:x ?: RACTupleNil.tupleNil];
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (disposable) {
				selfCompleted = YES;
				sendCompletedIfNecessary();
			}
		}];

		if (selfDisposable != nil) [disposable addDisposable:selfDisposable];

		RACDisposable *otherDisposable = [signal subscribeNext:^(id x) {
			@synchronized (disposable) {
				[otherValues addObject:x ?: RACTupleNil.tupleNil];
				sendNext();
			}
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			@synchronized (disposable) {
				otherCompleted = YES;
				sendCompletedIfNecessary();
			}
		}];

		if (otherDisposable != nil) [disposable addDisposable:otherDisposable];

		return disposable;
	}] setNameWithFormat:@"[%@] -zipWith: %@", self.name, signal];
}

@end

@implementation RACSignal (Subscription)

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber disposable:disposable];
	
	OSSpinLockLock(&_subscribersLock);
	if (_subscribers == nil) _subscribers = [[NSMutableArray alloc] init];
	[_subscribers addObject:subscriber];
	OSSpinLockUnlock(&_subscribersLock);
	
	@weakify(self, subscriber);
	RACDisposable *defaultDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self, subscriber);
		if (self == nil) return;

		BOOL stillHasSubscribers = YES;

		OSSpinLockLock(&_subscribersLock);
		[_subscribers removeObjectIdenticalTo:subscriber];
		stillHasSubscribers = _subscribers.count > 0;
		OSSpinLockUnlock(&_subscribersLock);
		
		if (!stillHasSubscribers) {
			[self invalidateGlobalRefIfNoNewSubscribersShowUp];
		}
	}];

	[disposable addDisposable:defaultDisposable];

	if (self.didSubscribe != NULL) {
		RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
			RACDisposable *innerDisposable = self.didSubscribe(subscriber);
			if (innerDisposable != nil) [disposable addDisposable:innerDisposable];
		}];

		if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
	}
	
	[subscriber didSubscribeWithDisposable:disposable];
	
	return disposable;
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
		timeout:RACSignalAsynchronousWaitTimeout]
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
	[[self ignoreElements] asynchronousFirstOrDefault:nil success:&success error:error];
	return success;
}

@end
