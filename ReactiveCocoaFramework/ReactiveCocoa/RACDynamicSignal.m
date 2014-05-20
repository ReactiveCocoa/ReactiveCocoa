//
//  RACDynamicSignal.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignal.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
#import "RACPassthroughSubscriber.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"
#import <libkern/OSAtomic.h>

// Retains dynamic signals while they wait for subscriptions.
//
// This set must only be used on the main thread.
static CFMutableSetRef RACActiveSignals = nil;

// A linked list of RACDynamicSignals, used in RACActiveSignalsToCheck.
typedef struct RACSignalList {
	CFTypeRef retainedSignal;
	struct RACSignalList * restrict next;
} RACSignalList;

// An atomic queue of signals to check for subscribers. If any signals with zero
// subscribers are found in this queue, they are removed from RACActiveSignals.
static OSQueueHead RACActiveSignalsToCheck = OS_ATOMIC_QUEUE_INIT;

// Whether RACActiveSignalsToCheck will be enumerated on the next iteration on
// the main run loop.
static volatile uint32_t RACWillCheckActiveSignals = 0;

@interface RACDynamicSignal () {
	// Contains all subscribers to the receiver.
	//
	// All access to this array must be synchronized using `_subscribersLock`.
	NSMutableArray *_subscribers;

	// Synchronizes access to `_subscribers`.
	OSSpinLock _subscribersLock;
}

// The block to invoke for each subscriber.
@property (nonatomic, copy, readonly) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);

@end

@implementation RACDynamicSignal

#pragma mark Lifecycle

+ (void)initialize {
	if (self != RACDynamicSignal.class) return;

	CFSetCallBacks callbacks = kCFTypeSetCallBacks;

	// Use pointer equality and hashes for membership testing.
	callbacks.equal = NULL;
	callbacks.hash = NULL;

	RACActiveSignals = CFSetCreateMutable(NULL, 0, &callbacks);
}

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	RACDynamicSignal *signal = [[self alloc] init];
	signal->_didSubscribe = [didSubscribe copy];
	return [signal setNameWithFormat:@"+createSignal:"];
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

	RACSignalList * restrict elem;

	while ((elem = OSAtomicDequeue(&RACActiveSignalsToCheck, offsetof(RACSignalList, next))) != NULL) {
		RACDynamicSignal *signal = CFBridgingRelease(elem->retainedSignal);
		free(elem);

		if (signal.hasSubscribers) {
			// We want to keep the signal around until all its subscribers are done
			CFSetAddValue(RACActiveSignals, (__bridge void *)signal);
		} else {
			CFSetRemoveValue(RACActiveSignals, (__bridge void *)signal);
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

- (BOOL)hasSubscribers {
	OSSpinLockLock(&_subscribersLock);
	BOOL hasSubscribers = _subscribers.count > 0;
	OSSpinLockUnlock(&_subscribersLock);

	return hasSubscribers;
}

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];

	OSSpinLockLock(&_subscribersLock);
	if (_subscribers == nil) {
		_subscribers = [NSMutableArray arrayWithObject:subscriber];
	} else {
		[_subscribers addObject:subscriber];
	}
	OSSpinLockUnlock(&_subscribersLock);
	
	@weakify(self);
	RACDisposable *defaultDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);
		if (self == nil) return;

		BOOL stillHasSubscribers = YES;

		OSSpinLockLock(&_subscribersLock);
		{
			// Since newer subscribers are generally shorter-lived, search
			// starting from the end of the list.
			NSUInteger index = [_subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
				return obj == subscriber;
			}];

			if (index != NSNotFound) {
				[_subscribers removeObjectAtIndex:index];
				stillHasSubscribers = _subscribers.count > 0;
			}
		}
		OSSpinLockUnlock(&_subscribersLock);
		
		if (!stillHasSubscribers) {
			[self invalidateGlobalRefIfNoNewSubscribersShowUp];
		}
	}];

	[disposable addDisposable:defaultDisposable];

	if (self.didSubscribe != NULL) {
		RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
			RACDisposable *innerDisposable = self.didSubscribe(subscriber);
			[disposable addDisposable:innerDisposable];
		}];

		[disposable addDisposable:schedulingDisposable];
	}
	
	return disposable;
}

@end
