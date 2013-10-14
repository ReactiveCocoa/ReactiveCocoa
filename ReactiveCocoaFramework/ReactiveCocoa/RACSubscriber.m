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

@interface RACSubscriber ()

// A private serial queue used to implement backpressure against any signals
// that the receiver is subscribed to.
//
// While the receiver is processing events, the queue will be suspended. To wait
// for the receiver to be ready, enqueue a block here.
//
// This queue is retained.
@property (nonatomic, readonly) dispatch_queue_t readyQueue;

// These callbacks should only be accessed while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);

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

	_readyQueue = dispatch_queue_create("com.github.ReactiveCocoa.RACSubscriber.readyQueue", DISPATCH_QUEUE_SERIAL);
	dispatch_set_target_queue(_readyQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));

	@weakify(self);

	RACDisposable *selfDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);
		if (self == nil) return;

		@synchronized (self) {
			self.next = nil;
			self.error = nil;
			self.completed = nil;
		}
	}];

	_disposable = [RACCompoundDisposable compoundDisposable];
	[_disposable addDisposable:selfDisposable];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];

	if (_readyQueue != NULL) {
		dispatch_release(_readyQueue);
		_readyQueue = NULL;
	}
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	dispatch_suspend(self.readyQueue);
	@onExit {
		dispatch_resume(self.readyQueue);
	};

	@synchronized (self) {
		void (^nextBlock)(id) = [self.next copy];
		if (nextBlock == nil) return;

		nextBlock(value);
	}
}

- (void)sendError:(NSError *)e {
	dispatch_suspend(self.readyQueue);
	@onExit {
		dispatch_resume(self.readyQueue);
	};

	@synchronized (self) {
		void (^errorBlock)(NSError *) = [self.error copy];
		[self.disposable dispose];

		if (errorBlock == nil) return;
		errorBlock(e);
	}
}

- (void)sendCompleted {
	dispatch_suspend(self.readyQueue);
	@onExit {
		dispatch_resume(self.readyQueue);
	};

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
	RACDisposable *blockDisposable = [[RACDisposable alloc] init];
	[self.disposable addDisposable:blockDisposable];

	dispatch_async(self.readyQueue, ^{
		if (blockDisposable.disposed) return;
		[self.disposable removeDisposable:blockDisposable];

		block(self);
	});

	return blockDisposable;
}

@end
