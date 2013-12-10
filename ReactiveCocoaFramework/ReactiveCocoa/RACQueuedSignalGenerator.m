//
//  RACQueuedSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueuedSignalGenerator.h"
#import "EXTScope.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import <libkern/OSAtomic.h>

@interface RACQueuedSignalGenerator () {
	// Although RACReplaySubject is deprecated for consumers, we're going to use it
	// internally for the foreseeable future. We just want to expose something
	// higher level.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	RACReplaySubject *_executing;
	#pragma clang diagnostic pop

	// An atomic counter used to inform the `executing` signal.
	volatile int32_t _executingCount;

	RACSubject *_enqueuedSignals;
}

/// The generator used to create the signals that will be enqueued.
@property (nonatomic, strong, readonly) RACSignalGenerator *generator;

/// A signal of the enqueued signals.
///
/// Unlike `enqueuedSignals`, the inner signals here will trigger side effects
/// upon subscription.
@property (nonatomic, strong, readonly) RACSubject *queue;

@end

@implementation RACQueuedSignalGenerator

#pragma mark Lifecycle

+ (instancetype)queuedGeneratorWithGenerator:(RACSignalGenerator *)generator {
	return [[self alloc] initWithGenerator:generator];
}

- (id)initWithGenerator:(RACSignalGenerator *)generator {
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_generator = generator;
	_queue = [[RACSubject subject] setNameWithFormat:@"queue"];
	_enqueuedSignals = [[RACSubject subject] setNameWithFormat:@"enqueuedSignals"];

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	_executing = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"executing"];
	#pragma clang diagnostic pop

	[[[[[self.queue
		flatten:1 withPolicy:RACSignalFlattenPolicyQueue]
		// Each signal of work will send the current value of `_executingCount`
		// (as set up in -enqueueSignal:), so map that to an "executing" BOOL.
		map:^(NSNumber *count) {
			return @(count.integerValue > 0);
		}]
		startWith:@NO]
		distinctUntilChanged]
		subscribe:_executing];

	return self;
}

- (void)dealloc {
	[_enqueuedSignals sendCompleted];
	[self.queue sendCompleted];
}

#pragma mark Generation

- (void)enqueueSignal:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	RACSignal *endSignal = [RACSignal defer:^{
		int32_t newCount = OSAtomicDecrement32Barrier(&_executingCount);
		return [RACSignal return:@(newCount)];
	}];

	RACSignal *startSignal = [RACSignal defer:^{
		// Increment `_executingCount` before any work actually begins.
		int32_t newCount = OSAtomicIncrement32Barrier(&_executingCount);
		
		return [[[signal
			ignoreValues]
			startWith:@(newCount)]
			doDisposed:^{
				// When this signal terminates, enqueue a signal that will
				// decrement `_executingCount`. We put this onto the queue so
				// that any existing work signals are processed first, and
				// `_executingCount` remains non-zero while work is still
				// enqueued.
				[self.queue sendNext:endSignal];
			}];
	}];

	[self.queue sendNext:startSignal];
}

- (RACSignal *)signalWithValue:(id)input {
	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			RACSubject *subject = [[RACSubject subject] setNameWithFormat:@"%@ -enqueuedSignals (value %@)", self, [input rac_description]];
			[subject subscribe:subscriber];

			// Create and enqueue a signal that will start the generated signal
			// upon subscription.
			RACSignal *queueSignal = [RACSignal create:^(id<RACSubscriber> queueSubscriber) {
				[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
					// When the subscription to the generated signal is disposed
					// (for any reason), remove this signal from the queue.
					[queueSubscriber sendCompleted];

					// Also notify any subscribers of `enqueuedSignals`, in case
					// the signal was canceled.
					[subject sendCompleted];
				}]];

				if (subscriber.disposable.disposed) return;

				// Kick off the generated signal itself.
				[[self.generator
					signalWithValue:input]
					subscribeSavingDisposable:^(RACDisposable *disposable) {
						// Allow the subscriber to -signalWithValue: to dispose
						// of the generated signal.
						[subscriber.disposable addDisposable:disposable];
					} next:^(id x) {
						[subject sendNext:x];
					} error:^(NSError *error) {
						[subject sendError:error];
					} completed:^{
						[subject sendCompleted];
					}];
			}];

			// Ensure that signals are pushed onto `enqueuedSignals` and `queue`
			// in the same order (without interference from other threads).
			@synchronized (self) {
				[_enqueuedSignals sendNext:subject];
				[self enqueueSignal:queueSignal];
			}
		}]
		setNameWithFormat:@"%@ -signalWithValue: %@", self, [input rac_description]];
}

@end
