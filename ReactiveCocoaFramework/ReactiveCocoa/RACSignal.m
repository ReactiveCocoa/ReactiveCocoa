//
//  RACSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "NSObject+RACExtensions.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSubject.h"
#import "RACSignal+Private.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACBlockTrampoline.h"
#import <libkern/OSAtomic.h>

static NSMutableSet *activeSignals() {
	static dispatch_once_t onceToken;
	static NSMutableSet *activeSignal = nil;
	dispatch_once(&onceToken, ^{
		activeSignal = [[NSMutableSet alloc] init];
	});
	
	return activeSignal;
}

@interface RACSignal ()
@property (assign, getter=isTearingDown) BOOL tearingDown;
@end

@implementation RACSignal

- (instancetype)init {
	self = [super init];
	if(self == nil) return nil;
	
	// We want to keep the signal around until all its subscribers are done
	@synchronized(activeSignals()) {
		[activeSignals() addObject:self];
	}
	
	self.tearingDown = NO;
	self.subscribers = [NSMutableArray array];
	
	// As soon as we're created we're already trying to be released. Such is life.
	[self invalidateGlobalRefIfNoNewSubscribersShowUp];
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> name: %@", NSStringFromClass([self class]), self, self.name];
}

#pragma mark RACStream

+ (instancetype)empty {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
		return nil;
	}];
}

+ (instancetype)return:(id)value {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
		return nil;
	}];
}

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	NSParameterAssert(block != NULL);

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

	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACStreamBindBlock bindingBlock = block();

		NSMutableArray *signals = [NSMutableArray arrayWithObject:self];
		NSMutableArray *disposables = [NSMutableArray array];

		// Works around the issue described in #94 by making sure -bind: doesn't
		// send more values than it should. This doesn't help the subscription
		// actually terminate properly, though.
		__block volatile uint32_t stopBinding = 0;

		void (^disposeAll)(void) = ^{
			OSAtomicOr32Barrier(1, &stopBinding);

			@synchronized (disposables) {
				[disposables makeObjectsPerformSelector:@selector(dispose)];
			}
		};

		void (^completeSignal)(id<RACSignal>) = ^(id<RACSignal> signal) {
			@synchronized (signals) {
				[signals removeObject:signal];

				if (signals.count == 0) {
					[subscriber sendCompleted];
					[disposables makeObjectsPerformSelector:@selector(dispose)];
				}
			}
		};

		void (^addSignal)(id<RACSignal>) = ^(id<RACSignal> signal) {
			@synchronized (signals) {
				[signals addObject:signal];
			}

			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[subscriber sendNext:x];
			} error:^(NSError *error) {
				disposeAll();
				[subscriber sendError:error];
			} completed:^{
				completeSignal(signal);
			}];

			if (disposable != nil) {
				@synchronized (disposables) {
					[disposables addObject:disposable];
				}
			}
		};

		RACDisposable *bindingDisposable = [self subscribeNext:^(id x) {
			if (stopBinding) return;
			
			BOOL stop = NO;
			id<RACSignal> signal = bindingBlock(x, &stop);

			if (signal != nil) addSignal(signal);

			if (signal == nil || stop) {
				OSAtomicOr32Barrier(1, &stopBinding);
				completeSignal(self);
			}
		} error:^(NSError *error) {
			if (stopBinding) return;

			disposeAll();
			[subscriber sendError:error];
		} completed:^{
			if (stopBinding) return;

			OSAtomicOr32Barrier(1, &stopBinding);
			completeSignal(self);
		}];

		if (bindingDisposable != nil) {
			@synchronized (disposables) {
				[disposables addObject:bindingDisposable];
			}
		}

		return [RACDisposable disposableWithBlock:^{
			disposeAll();
		}];
	}];
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:block(x)];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];
}

- (RACSignal *)concat:(id<RACSignal>)signal {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACDisposable *concattedDisposable = nil;
		RACDisposable *sourceDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			concattedDisposable = [signal subscribe:[RACSubscriber subscriberWithNext:^(id x) {
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

- (instancetype)flatten {
	return [self flatten:0];
}

+ (instancetype)zip:(NSArray *)signals reduce:(id)reduceBlock {
	if (signals.count == 0) return self.empty;
	signals = [signals copy];
	NSUInteger numSignals = signals.count;
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		NSMutableArray *disposables = [NSMutableArray arrayWithCapacity:numSignals];
		NSMutableArray *completedOrErrorBySignal = [NSMutableArray arrayWithCapacity:numSignals];
		NSMutableArray *valuesBySignal = [NSMutableArray arrayWithCapacity:numSignals];
		for (NSUInteger i = 0; i < numSignals; ++i) {
			[completedOrErrorBySignal addObject:@NO];
			[valuesBySignal addObject:NSMutableArray.array];
		}
		
		void (^sendCompleteOrErrorIfNecessary)(void) = ^{
			NSError *error = nil;
			for (NSUInteger i = 0; i < numSignals; ++i) {
				if ([valuesBySignal[i] count] == 0) {
					id completedOrError = completedOrErrorBySignal[i];
					if ([completedOrError isKindOfClass:NSError.class]) {
						error = completedOrError;
					} else {
						if ([completedOrError isEqual:@YES]) {
							[subscriber sendCompleted];
						}
						return;
					}
				}
			}
			if (error != nil) {
				[subscriber sendError:error];
			}
		};
		
		for (NSUInteger i = 0; i < numSignals; ++i) {
			id<RACSignal> signal = signals[i];
			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				@synchronized(valuesBySignal) {
					[valuesBySignal[i] addObject:x ?: RACTupleNil.tupleNil];
					
					BOOL isMissingValues = NO;
					NSMutableArray *earliestValues = [NSMutableArray arrayWithCapacity:numSignals];
					for (NSUInteger j = 0; j < numSignals; ++j) {
						NSArray *nexts = valuesBySignal[j];
						if (nexts.count == 0) {
							isMissingValues = YES;
							break;
						}
						[earliestValues addObject:nexts[0]];
					}
					
					if (!isMissingValues) {
						for (NSMutableArray *nexts in valuesBySignal) {
							[nexts removeObjectAtIndex:0];
						}
						
						if (reduceBlock == NULL) {
							[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:earliestValues]];
						} else {
							[subscriber sendNext:[RACBlockTrampoline invokeBlock:reduceBlock withArguments:earliestValues]];
						}
					}
					
					sendCompleteOrErrorIfNecessary();
				}
			} error:^(NSError *error) {
				@synchronized(valuesBySignal) {
					completedOrErrorBySignal[i] = error;
					sendCompleteOrErrorIfNecessary();
				}
			} completed:^{
				@synchronized(valuesBySignal) {
					completedOrErrorBySignal[i] = @YES;
					sendCompleteOrErrorIfNecessary();
				}
			}];
			
			if (disposable != nil) {
				[disposables addObject:disposable];
			}
		}
		
		return [RACDisposable disposableWithBlock:^{
			[disposables makeObjectsPerformSelector:@selector(dispose)];
		}];
	}];
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	@synchronized(self.subscribers) {
		[self.subscribers addObject:subscriber];
	}
	
	__weak id weakSelf = self;
	__weak id weakSubscriber = subscriber;
	RACDisposable *defaultDisposable = [RACDisposable disposableWithBlock:^{
		RACSignal *strongSelf = weakSelf;
		id<RACSubscriber> strongSubscriber = weakSubscriber;
		// If the disposal is happening because the signal's being torn down, we
		// don't need to duplicate the invalidation.
		if(!strongSelf.tearingDown) {
			BOOL stillHasSubscribers = YES;
			@synchronized(strongSelf.subscribers) {
				[strongSelf.subscribers removeObject:strongSubscriber];
				stillHasSubscribers = strongSelf.subscribers.count > 0;
			}
			
			if(!stillHasSubscribers) {
				[strongSelf invalidateGlobalRefIfNoNewSubscribersShowUp];
			}
		}
	}];

	RACDisposable *disposable = defaultDisposable;
	if(self.didSubscribe != NULL) {
		RACDisposable *innerDisposable = self.didSubscribe(subscriber);
		disposable = [RACDisposable disposableWithBlock:^{
			[innerDisposable dispose];
			[defaultDisposable dispose];
		}];
	}
	
	[subscriber didSubscribeWithDisposable:disposable];
	
	return disposable;
}


#pragma mark API

@synthesize didSubscribe;
@synthesize subscribers;
@synthesize tearingDown;
@synthesize name;

+ (instancetype)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSignal *signal = [[RACSignal alloc] init];
	signal.didSubscribe = didSubscribe;
	return signal;
}

+ (instancetype)error:(NSError *)error {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
		return nil;
	}];
}

+ (instancetype)never {
	return [self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		return nil;
	}];
}

+ (RACSignal *)start:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:[RACScheduler backgroundScheduler] block:block];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:scheduler subjectBlock:^(RACSubject *subject) {
		BOOL success = YES;
		NSError *error = nil;
		id returned = block(&success, &error);
		
		if(!success) {
			[subject sendError:error];
		} else {
			[subject sendNext:returned];
			[subject sendCompleted];
		}
	}];
}

+ (RACSignal *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block {
	NSParameterAssert(block != NULL);

	RACReplaySubject *subject = [RACReplaySubject subject];
	[scheduler schedule:^{
		block(subject);
	}];
	
	return subject;
}

- (void)invalidateGlobalRefIfNoNewSubscribersShowUp {
	// We might not be on a queue with a runloop. So make sure we do the delay
	// on the main queue.
	dispatch_async(dispatch_get_main_queue(), ^{
		// If no one subscribed in the runloop's pass, then we're free to go.
		// It's up to the caller to keep us alive if they still want us.
		[self rac_performBlock:^{
			BOOL hasSubscribers = YES;
			@synchronized(self.subscribers) {
				hasSubscribers = self.subscribers.count > 0;
			}

			if (!hasSubscribers) {
				[self invalidateGlobalRef];
			}
		} afterDelay:0];
	});
}

- (void)invalidateGlobalRef {
	@synchronized(activeSignals()) {
		[activeSignals() removeObject:self];
	}
}

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block {
	NSParameterAssert(block != NULL);

	NSArray *currentSubscribers = nil;
	@synchronized(self.subscribers) {
		currentSubscribers = [self.subscribers copy];
	}
	
	for(id<RACSubscriber> subscriber in currentSubscribers) {
		block(subscriber);
	}
}

- (void)tearDown {
	self.tearingDown = YES;
	
	@synchronized(self.subscribers) {
		[self.subscribers removeAllObjects];
	}
	
	[self invalidateGlobalRef];
}

@end
