//
//  RACSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "NSObject+RACExtensions.h"
#import "RACAsyncSubject.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
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

// TODO: Implement this as a primitive, instead of depending on -flatten.
- (instancetype)bind:(id (^)(id value, BOOL *stop))block {
	NSParameterAssert(block != NULL);

	RACSignal *signalsSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			BOOL stop = NO;
			id<RACSignal> signal = block(x, &stop);

			if (signal == nil) {
				[subscriber sendCompleted];
				return;
			}

			[subscriber sendNext:signal];
			if (stop) [subscriber sendCompleted];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];

	return signalsSignal.flatten;
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
	static NSValue *(^keyForSignal)(id<RACSignal>) = ^ NSValue * (id<RACSignal> signal) {
		return [NSValue valueWithNonretainedObject:signal];
	};
	
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:signals.count];
		NSMutableDictionary *completedOrErrorBySignal = [NSMutableDictionary dictionaryWithCapacity:signals.count];
		NSMutableDictionary *valuesBySignal = [NSMutableDictionary dictionaryWithCapacity:signals.count];
		for (id<RACSignal> signal in signals) {
			valuesBySignal[keyForSignal(signal)] = NSMutableArray.array;
		}
		
		void (^sendCompleteOrErrorIfNecessary)(void) = ^{
			NSError *error = nil;
			for (id<RACSignal> signal in signals) {
				if ([valuesBySignal[keyForSignal(signal)] count] == 0) {
					id completedOrError = completedOrErrorBySignal[keyForSignal(signal)];
					if ([completedOrError isKindOfClass:NSError.class]) {
						error = completedOrError;
						continue;
					}
					if (completedOrError != nil) {
						[subscriber sendCompleted];
					}
					return;
				}
			}
			if (error != nil) {
				[subscriber sendError:error];
			}
		};
		
		for (id<RACSignal> signal in signals) {
			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				@synchronized(valuesBySignal) {
					[valuesBySignal[keyForSignal(signal)] addObject:x ? : RACTupleNil.tupleNil];
					
					BOOL isMissingValues = NO;
					NSMutableArray *earliestValues = [NSMutableArray arrayWithCapacity:signals.count];
					for (id<RACSignal> signal in signals) {
						NSArray *values = valuesBySignal[keyForSignal(signal)];
						if (values.count == 0) {
							isMissingValues = YES;
							break;
						}
						[earliestValues addObject:values[0]];
					}
					
					if (!isMissingValues) {
						for (NSMutableArray *values in valuesBySignal.allValues) {
							[values removeObjectAtIndex:0];
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
					if (completedOrErrorBySignal[keyForSignal(signal)] == nil) {
						completedOrErrorBySignal[keyForSignal(signal)] = error;
					}
					sendCompleteOrErrorIfNecessary();
				}
			} completed:^{
				@synchronized(valuesBySignal) {
					if (completedOrErrorBySignal[keyForSignal(signal)] == nil) {
						completedOrErrorBySignal[keyForSignal(signal)] = @YES;
					}
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

- (NSArray *)toArray {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = @(__func__);
  
	NSMutableArray *values = [NSMutableArray array];
	__block BOOL done = NO;
	[self subscribeNext:^(id x) {
		[values addObject:x ? : [NSNull null]];
	} error:^(NSError *error) {
		[condition lock];
		done = YES;
		[condition broadcast];
		[condition unlock];
	} completed:^{
		[condition lock];
		done = YES;
		[condition broadcast];
		[condition unlock];
	}];
  
	[condition lock];
	while (!done) {
		[condition wait];
	}
  
	[condition unlock];
  
	return [values copy];
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

	RACAsyncSubject *subject = [RACAsyncSubject subject];
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
