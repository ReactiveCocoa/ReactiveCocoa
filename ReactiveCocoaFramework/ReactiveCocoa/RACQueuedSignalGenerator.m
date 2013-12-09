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
}

/// The generator used to create the signals that will be enqueued.
@property (nonatomic, strong, readonly) RACSignalGenerator *generator;

/// A signal of the enqueued signals.
@property (nonatomic, strong, readonly) RACSubject *signals;

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
	_signals = [[RACSubject subject] setNameWithFormat:@"signals"];

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	_executing = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"executing"];
	#pragma clang diagnostic pop

	[[[[[self.signals
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
	[self.signals sendCompleted];
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
				[self.signals sendNext:endSignal];
			}];
	}];

	[self.signals sendNext:startSignal];
}

- (RACSignal *)signalWithValue:(id)input {
	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			// Create and enqueue a signal that will start the generated signal
			// upon subscription.
			RACSignal *queueSignal = [RACSignal create:^(id<RACSubscriber> queueSubscriber) {
				// When the subscription to the generated signal is disposed
				// (for any reason), remove this signal from the queue.
				[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
					[queueSubscriber sendCompleted];
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
						[subscriber sendNext:x];
					} error:^(NSError *error) {
						[subscriber sendError:error];
					} completed:^{
						[subscriber sendCompleted];
					}];
			}];

			[self enqueueSignal:queueSignal];
		}]
		setNameWithFormat:@"%@ -signalWithValue: %@", self, [input rac_description]];
}

@end
