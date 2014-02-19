#import "RACInOrderScheduler.h"
#import <libkern/OSAtomic.h>

struct RACInOrderSchedulerQueueNode {
	void* block;
	void* next;
};

@implementation RACInOrderScheduler {
// producers atomically increment this counter when enqueueing
// whoever increments-from-zero becomes responsible for draining the queue
// after each action is run, the draining producer atomically decrements the counter
// must continue draining until the counter decrements-to-zero
@private int32_t _drainToZeroCounter;

// thread-safe queue for storing queued blocks
@private OSQueueHead _queue;
	
// the underlying scheduler that blocks will be run on
@private RACScheduler* _scheduler;
	
// used on fast path to quickly determine if we can avoid involving the scheduler
@private bool _isImmediate;
}

#pragma mark Lifecycle

-(instancetype)initWithScheduler:(RACScheduler*)scheduler {
	assert(scheduler != nil);
	if (self = [super init]) {
		self->_isImmediate = scheduler == RACScheduler.immediateScheduler;
		self->_scheduler = scheduler;
		self->_queue = (OSQueueHead)OS_ATOMIC_QUEUE_INIT;
	}
	return self;
}
-(instancetype)init {
	return [self initWithScheduler:RACScheduler.immediateScheduler];
}
+(RACInOrderScheduler*)inOrderSchedulerOnScheduler:(RACScheduler*)scheduler {
	return [[RACInOrderScheduler alloc] initWithScheduler:scheduler];
}

-(void(^)(void))_tryDequeueAction {
	// try dequeue
	void* dequeuedVoid = OSAtomicDequeue(&_queue, offsetof(struct RACInOrderSchedulerQueueNode, next));
	if (dequeuedVoid == NULL) return nil;

	// extract block
	struct RACInOrderSchedulerQueueNode* dequeuedNode = (struct RACInOrderSchedulerQueueNode*)dequeuedVoid;
	void(^dequeuedBlock)(void) = (__bridge_transfer void(^)(void))dequeuedNode->block;
	free(dequeuedVoid);
	
	return dequeuedBlock;
}

-(void)dealloc {
	// action queue should be empty, but empty it anyways just to be safe
	// e.g. maybe a scheduled block threw, putting this scheduler into a stuck state
	while ([self _tryDequeueAction] != nil) {
		// discard
	}
}

#pragma mark Queueing

-(void)_performDrain {
	do {
		// dequeue
		void(^action)(void) = [self _tryDequeueAction];
		assert(action != nil); // because of how _drainToZeroCounter is used
		
		// perform
		action();
		
		// try release draining responsibility
	} while (OSAtomicDecrement32Barrier(&_drainToZeroCounter) > 0);
}

-(void)_didSchedule:(void(^)(void))action {
	// attempt fast path
	if (OSAtomicCompareAndSwap32Barrier(0, 1, &_drainToZeroCounter)) {
		action();
		if (OSAtomicDecrement32Barrier(&_drainToZeroCounter) > 0) {
			[self _performDrain];
		}
		return;
	}
	
	// enqeue
	struct RACInOrderSchedulerQueueNode* n = (struct RACInOrderSchedulerQueueNode*)malloc(sizeof(struct RACInOrderSchedulerQueueNode));
	n->block = (__bridge_retained void*)action;
	n->next = NULL;
	OSAtomicEnqueue(&_queue, (void*)n, offsetof(struct RACInOrderSchedulerQueueNode, next));
	
	// try acquire draining responsibility
	if (OSAtomicIncrement32Barrier(&_drainToZeroCounter) > 1) return;
	
	// start draining
	[self _performDrain];
}

#pragma mark Scheduling

-(RACDisposable *)schedule:(void(^)(void))block {
	NSCParameterAssert(block != nil);
	
	// attempt fast path
	if (_isImmediate && OSAtomicCompareAndSwap32Barrier(0, 1, &_drainToZeroCounter)) {
		block();
		if (OSAtomicDecrement32Barrier(&_drainToZeroCounter) > 0) [self _performDrain];
		return nil;
	}
	
	return [_scheduler schedule:^{ [self _didSchedule:block]; }];
}

-(RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
	NSCParameterAssert(block != nil);
	return [_scheduler after:date
					schedule:^{ [self _didSchedule:block]; }];
}

-(RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
	NSCParameterAssert(block != nil);
	return [_scheduler after:date
			  repeatingEvery:interval
				  withLeeway:leeway
					schedule:^{ [self _didSchedule:block]; }];
}

@end
