//
//  RACQueuedSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueuedSignalGenerator.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

@interface RACQueuedSignalGenerator ()

/// The generator used to create the signals that will be enqueued.
@property (nonatomic, strong, readonly) RACSignalGenerator *generator;

/// A signal of the enqueued signals.
@property (nonatomic, strong, readonly) RACSubject *signals;

@end

@implementation RACQueuedSignalGenerator

#pragma mark Lifecycle

- (id)initWithGenerator:(RACSignalGenerator *)generator {
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_generator = generator;
	_signals = [[RACSubject subject] setNameWithFormat:@"signals"];

	[[self.signals
		flatten:1 withPolicy:RACSignalFlattenPolicyQueue]
		subscribe:nil];

	return self;
}

- (void)dealloc {
	[self.signals sendCompleted];
}

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			RACSubject *subject = [RACSubject subject];
			[subject subscribe:subscriber];

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
						[subject sendNext:x];
					} error:^(NSError *error) {
						[subject sendError:error];
					} completed:^{
						[subject sendCompleted];
					}];
			}];

			[self.signals sendNext:queueSignal];
		}]
		setNameWithFormat:@"%@ -signalWithValue: %@", self, [input rac_description]];
}

@end
