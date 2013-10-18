//
//  RACSubscriber.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"
#import "RACSubscriber+Private.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
#import <libkern/OSAtomic.h>

// The minimum value for `_eventCount`, used to indicate that no events are
// being processed.
static const int32_t RACSubscriberMinimumEventCount = INT32_MIN;

@interface RACSubscriber () {
	// Incremented when events are being processed or waiting to be processed.
	//
	// Note that this variable does not actually correspond to the _number_ of
	// events inflight, since it starts at `RACSubscriberMinimumEventCount`.
	//
	// This should only be used atomically.
	volatile int32_t _eventCount;
}

// Callbacks to invoke when the subscriber receives events. These should only be
// accessed and invoked while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);

// An array of `dispatch_block_t` objects.
//
// While `_eventCount` is `RACSubscriberMinimumEventCount`, blocks in this array
// should be popped from the end and invoked.
//
// This should only be mutated while synchronized on the array.
@property (nonatomic, strong, readonly) NSMutableArray *dispatchBlocksWaiting;

// Contains disposables for all of the receiver's subscriptions.
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

@end

@implementation RACSubscriber

#pragma mark Lifecycle

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *subscriber = [[self alloc] init];

	subscriber->_next = [next copy];
	subscriber->_error = [error copy];
	subscriber->_completed = [completed copy];

	return subscriber;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_dispatchBlocksWaiting = [[NSMutableArray alloc] init];
	_eventCount = RACSubscriberMinimumEventCount;

	@weakify(self);

	RACDisposable *selfDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);
		if (self == nil) return;

		@synchronized (self) {
			self.next = nil;
			self.error = nil;
			self.completed = nil;
		}

		@synchronized (self.dispatchBlocksWaiting) {
			[self.dispatchBlocksWaiting removeAllObjects];
		}
	}];

	_disposable = [RACCompoundDisposable compoundDisposable];
	[_disposable addDisposable:selfDisposable];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark Backpressure

- (void)suspendSignals {
	int32_t oldCount;
	do {
		oldCount = _eventCount;
		if (oldCount == INT32_MAX) {
			// An increment would overflow, so just do nothing.
			break;
		}
	} while (!OSAtomicCompareAndSwap32Barrier(oldCount, oldCount + 1, &_eventCount));
}

- (void)resumeSignals {
	int32_t oldCount;
	do {
		oldCount = _eventCount;
		if (oldCount == RACSubscriberMinimumEventCount) {
			// A decrement would underflow, so just bail. Although this may
			// cause `dispatchBlocksWaiting` to be popped too early, that's not
			// as harmful as never running any of them again.
			break;
		}
	} while (!OSAtomicCompareAndSwap32Barrier(oldCount, oldCount - 1, &_eventCount));

	@synchronized (self.dispatchBlocksWaiting) {
		do {
			dispatch_block_t block = self.dispatchBlocksWaiting.lastObject;
			if (block == nil) break;

			[self.dispatchBlocksWaiting removeLastObject];
			block();
		} while (_eventCount == RACSubscriberMinimumEventCount);
	}
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self suspendSignals];

	@synchronized (self) {
		@onExit {
			[self resumeSignals];
		};

		void (^nextBlock)(id) = [self.next copy];

		if (nextBlock == nil) return;
		nextBlock(value);
	}
}

- (void)sendError:(NSError *)e {
	// This suspension is intentionally unbalanced, because we'll never be ready
	// for another event after terminating.
	[self suspendSignals];

	@synchronized (self) {
		void (^errorBlock)(NSError *) = [self.error copy];
		[self.disposable dispose];

		if (errorBlock == nil) return;
		errorBlock(e);
	}
}

- (void)sendCompleted {
	// This suspension is intentionally unbalanced, because we'll never be ready
	// for another event after terminating.
	[self suspendSignals];

	@synchronized (self) {
		void (^completedBlock)(void) = [self.completed copy];
		[self.disposable dispose];

		if (completedBlock == nil) return;
		completedBlock();
	}
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	if (d != nil) [self.disposable addDisposable:d];
}

- (RACDisposable *)invokeWhenReady:(void (^)(id<RACSubscriber>))block {
	NSCParameterAssert(block != nil);
	if (self.disposable.disposed) return nil;

	if (_eventCount == RACSubscriberMinimumEventCount) {
		block(self);
		return nil;
	}

	__block RACDisposable *blockDisposable = nil;

	dispatch_block_t dispatchBlock = [^{
		[self.disposable removeDisposable:blockDisposable];

		block(self);
	} copy];

	blockDisposable = [RACDisposable disposableWithBlock:^{
		@synchronized (self.dispatchBlocksWaiting) {
			[self.dispatchBlocksWaiting removeObject:dispatchBlock];
		}
	}];

	@synchronized (self.dispatchBlocksWaiting) {
		[self.dispatchBlocksWaiting insertObject:dispatchBlock atIndex:0];
	}

	[self.disposable addDisposable:blockDisposable];
	return blockDisposable;
}

@end
