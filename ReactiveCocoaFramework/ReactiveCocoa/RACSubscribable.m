//
//  RACSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"
#import "NSObject+RACExtensions.h"
#import "RACAsyncSubject.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACScheduler.h"
#import "RACSubject.h"
#import "RACSubscribable+Private.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACBlockTrampoline.h"
#import <libkern/OSAtomic.h>

static NSMutableSet *activeSubscribables() {
	static dispatch_once_t onceToken;
	static NSMutableSet *activeSubscribables = nil;
	dispatch_once(&onceToken, ^{
		activeSubscribables = [[NSMutableSet alloc] init];
	});
	
	return activeSubscribables;
}

@interface RACSubscribable ()
@property (assign, getter=isTearingDown) BOOL tearingDown;
@end

@implementation RACSubscribable

- (instancetype)init {
	self = [super init];
	if(self == nil) return nil;
	
	// We want to keep the subscribable around until all its subscribers are done
	@synchronized(activeSubscribables()) {
		[activeSubscribables() addObject:self];
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
	return [self createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
		return nil;
	}];
}

+ (instancetype)return:(id)value {
	return [self createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
		return nil;
	}];
}

// TODO: Implement this as a primitive, instead of depending on -flatten.
- (instancetype)bind:(id (^)(id value, BOOL *stop))block {
	NSParameterAssert(block != NULL);

	RACSubscribable *subscribablesSubscribable = [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			BOOL stop = NO;
			id<RACSubscribable> subscribable = block(x, &stop);

			if (subscribable == nil) {
				[subscriber sendCompleted];
				return;
			}

			[subscriber sendNext:subscribable];
			if (stop) [subscriber sendCompleted];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];

	return subscribablesSubscribable.flatten;
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		return [self subscribeNext:^(id x) {
			[subscriber sendNext:block(x)];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
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

- (instancetype)flatten {
	return [self flatten:0];
}

+ (instancetype)zip:(NSArray *)subscribables reduce:(id)reduceBlock {
	static NSString *(^keyForSubscribable)(id<RACSubscribable>) = ^ NSString * (id<RACSubscribable> subscribable) {
		return [NSString stringWithFormat:@"%p", subscribable];
	};
	
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		NSMutableSet *disposables = [NSMutableSet setWithCapacity:subscribables.count];
		NSMutableDictionary *completedOrErrorBySubscribable = [NSMutableDictionary dictionaryWithCapacity:subscribables.count];
		NSMutableDictionary *valuesBySubscribable = [NSMutableDictionary dictionaryWithCapacity:subscribables.count];
		for (id<RACSubscribable> subscribable in subscribables) {
			[valuesBySubscribable setObject:NSMutableArray.array forKey:[NSString stringWithFormat:@"%p", subscribable]];
		}
		
		void (^sendCompleteOrErrorIfNecessary)(void) = ^{
			BOOL completed = NO;
			NSError *error = nil;
			for (id<RACSubscribable> subscribable in subscribables) {
				if ([valuesBySubscribable[keyForSubscribable(subscribable)] count] != 0) {
					continue;
				}
				id completedOrError = completedOrErrorBySubscribable[keyForSubscribable(subscribable)];
				if (completedOrError == nil) {
					continue;
				}
				if ([completedOrError isKindOfClass:[NSError class]]) {
					error = completedOrError;
					continue;
				}
				completed = YES;
				break;
			}
			if (completed) {
				[subscriber sendCompleted];
				return;
			}
			if (error != nil) {
				[subscriber sendError:error];
			}
		};
		
		for (id<RACSubscribable> subscribable in subscribables) {
			RACDisposable *disposable = [subscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
				@synchronized(valuesBySubscribable) {
					[valuesBySubscribable[keyForSubscribable(subscribable)] addObject:x ? : RACTupleNil.tupleNil];
					
					BOOL isMissingValues = NO;
					NSMutableArray *earliestValues = [NSMutableArray arrayWithCapacity:subscribables.count];
					for (id<RACSubscribable> subscribable in subscribables) {
						NSArray *values = valuesBySubscribable[keyForSubscribable(subscribable)];
						if (values.count == 0) {
							isMissingValues = YES;
							break;
						}
						[earliestValues addObject:[values objectAtIndex:0]];
					}
					
					if (!isMissingValues) {
						for (NSMutableArray *values in valuesBySubscribable.allValues) {
							[values removeObjectAtIndex:0];
						}
						
						if (reduceBlock == NULL) {
							[subscriber sendNext:[RACTuple tupleWithObjectsFromArray:earliestValues]];
						} else {
							[subscriber sendNext:[RACBlockTrampoline invokeBlock:reduceBlock withArguments:earliestValues]];
						}
					}
					
					@synchronized(completedOrErrorBySubscribable) {
						sendCompleteOrErrorIfNecessary();
					}
				}
			} error:^(NSError *error) {
				@synchronized(completedOrErrorBySubscribable) {
					if (!completedOrErrorBySubscribable[keyForSubscribable(subscribable)]) {
						completedOrErrorBySubscribable[keyForSubscribable(subscribable)] = error;
					}
					@synchronized(valuesBySubscribable) {
						sendCompleteOrErrorIfNecessary();
					}
				}
			} completed:^{
				@synchronized(completedOrErrorBySubscribable) {
					if (!completedOrErrorBySubscribable[keyForSubscribable(subscribable)]) {
						completedOrErrorBySubscribable[keyForSubscribable(subscribable)] = @YES;
					}
					@synchronized(valuesBySubscribable) {
						sendCompleteOrErrorIfNecessary();
					}
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

#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSParameterAssert(subscriber != nil);
	
	@synchronized(self.subscribers) {
		[self.subscribers addObject:subscriber];
	}
	
	__weak id weakSelf = self;
	__weak id weakSubscriber = subscriber;
	RACDisposable *defaultDisposable = [RACDisposable disposableWithBlock:^{
		RACSubscribable *strongSelf = weakSelf;
		id<RACSubscriber> strongSubscriber = weakSubscriber;
		// If the disposal is happening because the subscribable's being torn
		// down, we don't need to duplicate the invalidation.
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

+ (instancetype)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACSubscribable *subscribable = [[RACSubscribable alloc] init];
	subscribable.didSubscribe = didSubscribe;
	return subscribable;
}

+ (instancetype)error:(NSError *)error {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
		return nil;
	}];
}

+ (instancetype)never {
	return [self createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
		return nil;
	}];
}

+ (RACSubscribable *)start:(id (^)(BOOL *success, NSError **error))block {
	return [self startWithScheduler:[RACScheduler backgroundScheduler] block:block];
}

+ (RACSubscribable *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block {
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

+ (RACSubscribable *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block {
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
	@synchronized(activeSubscribables()) {
		[activeSubscribables() removeObject:self];
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
