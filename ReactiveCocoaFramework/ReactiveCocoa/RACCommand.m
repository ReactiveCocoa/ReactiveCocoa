//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "EXTScope.h"
#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSerialDisposable.h"
#import "RACSignal+Operations.h"
#import <libkern/OSAtomic.h>

NSString * const RACCommandErrorDomain = @"RACCommandErrorDomain";

const NSInteger RACCommandErrorNotEnabled = 1;

@interface RACCommand () {
	// The mutable array backing `activeExecutionSignals`. This should only be
	// directly used from KVC mutation methods.
	NSMutableArray *_activeExecutionSignals;

	// Atomic backing variable for `allowsConcurrentExecution`.
	volatile uint32_t _allowsConcurrentExecution;
}

// An array of signals representing in-flight executions, in the order they
// began.
//
// This array should only be used on the main thread. This property is
// KVO-compliant, and should only be mutated using KVC.
@property (nonatomic, strong, readonly) NSArray *activeExecutionSignals;

// A scheduler that will enqueue work on the main thread, or perform it
// immediately if already running on the main thread.
//
// NOTE: Ensure you call this only in the context in which it'll be used! If you
// use it from a different scope, the returned scheduler will not change even if
// it's _used_ on another thread.
@property (nonatomic, strong, readonly) RACScheduler *reentrantMainThreadScheduler;

// Improves the performance of KVO on the receiver.
//
// See the documentation for <NSKeyValueObserving> for more information.
@property (atomic) void *observationInfo;

// The signal block that the receiver was initialized with.
@property (nonatomic, copy, readonly) RACSignal * (^signalBlock)(id input);

@end

@implementation RACCommand

#pragma mark Properties

- (BOOL)allowsConcurrentExecution {
	return _allowsConcurrentExecution != 0;
}

- (void)setAllowsConcurrentExecution:(BOOL)allowed {
	[self willChangeValueForKey:@keypath(self.allowsConcurrentExecution)];

	if (allowed) {
		OSAtomicOr32Barrier(1, &_allowsConcurrentExecution);
	} else {
		OSAtomicAnd32Barrier(0, &_allowsConcurrentExecution);
	}

	[self didChangeValueForKey:@keypath(self.allowsConcurrentExecution)];
}

- (RACScheduler *)reentrantMainThreadScheduler {
	if (RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler) {
		return RACScheduler.immediateScheduler;
	} else {
		return RACScheduler.mainThreadScheduler;
	}
}

- (NSArray *)activeExecutionSignals {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);

	return [_activeExecutionSignals copy];
}

- (void)setActiveExecutionSignals:(NSArray *)signals {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);

	[self willChangeValueForKey:@keypath(self.activeExecutionSignals)];
	_activeExecutionSignals.array = signals;
	[self didChangeValueForKey:@keypath(self.activeExecutionSignals)];
}

- (NSUInteger)countOfActiveExecutionSignals {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);

	return _activeExecutionSignals.count;
}

- (RACSignal *)objectInActiveExecutionSignalsAtIndex:(NSUInteger)index {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);

	return _activeExecutionSignals[index];
}

- (void)insertObject:(RACSignal *)signal inActiveExecutionSignalsAtIndex:(NSUInteger)index {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);
	NSCParameterAssert([signal isKindOfClass:RACSignal.class]);

	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
	[_activeExecutionSignals insertObject:signal atIndex:index];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
}

- (void)removeObjectFromActiveExecutionSignalsAtIndex:(NSUInteger)index {
	NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);

	NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:index];
	[self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
	[_activeExecutionSignals removeObjectAtIndex:index];
	[self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@keypath(self.activeExecutionSignals)];
}

#pragma mark Lifecycle

- (id)init {
	NSCAssert(NO, @"Use -initWithSignalBlock: instead");
	return nil;
}

- (id)initWithSignalBlock:(RACSignal * (^)(id input))signalBlock {
	return [self initWithEnabled:nil signalBlock:signalBlock];
}

- (id)initWithEnabled:(RACSignal *)enabledSignal signalBlock:(RACSignal * (^)(id input))signalBlock {
	NSCParameterAssert(signalBlock != nil);

	self = [super init];
	if (self == nil) return nil;

	_activeExecutionSignals = [[NSMutableArray alloc] init];
	_signalBlock = [signalBlock copy];

	@weakify(self);

	// `executionSignals`, but without errors automatically caught.
	RACMulticastConnection *rawExecutionSignals = [[[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			RACSerialDisposable *serialDisposable = [[RACSerialDisposable alloc] init];

			[self.reentrantMainThreadScheduler schedule:^{
				RACSignal *KVOSignal = [self rac_valuesAndChangesForKeyPath:@keypath(self.activeExecutionSignals) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial observer:nil];

				serialDisposable.disposable = [KVOSignal subscribeNext:^(id value) {
					NSCParameterAssert(RACScheduler.currentScheduler == RACScheduler.mainThreadScheduler);
					[subscriber sendNext:value];
				} error:^(NSError *error) {
					// Ensure that we only terminate this and all derived
					// signals on the main thread.
					//
					// We use the plain scheduler here, and not the property on
					// `self`, because we've been deallocated by this point.
					[RACScheduler.mainThreadScheduler schedule:^{
						[subscriber sendError:error];
					}];
				} completed:^{
					[RACScheduler.mainThreadScheduler schedule:^{
						[subscriber sendCompleted];
					}];
				}];
			}];

			return serialDisposable;
		}]
		reduceEach:^(id _, NSDictionary *change) {
			if ([change[NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeRemoval) return [RACSignal empty];

			NSArray *signals = change[NSKeyValueChangeNewKey];
			if (signals == nil) return [RACSignal empty];

			return [signals.rac_sequence signalWithScheduler:RACScheduler.immediateScheduler];
		}]
		flatten]
		publish];
	
	_executionSignals = [[rawExecutionSignals.signal
		map:^(RACSignal *signal) {
			return [signal catchTo:[RACSignal empty]];
		}]
		setNameWithFormat:@"%@ -executionSignals", self];
	
	RACMulticastConnection *errorsConnection = [[rawExecutionSignals.signal
		flattenMap:^(RACSignal *signal) {
			return [[signal
				ignoreValues]
				catch:^(NSError *error) {
					@strongify(self);
					return [[RACSignal return:error] deliverOn:self.reentrantMainThreadScheduler];
				}];
		}]
		publish];
	
	[rawExecutionSignals connect];
	
	_errors = [errorsConnection.signal setNameWithFormat:@"%@ -errors", self];
	[errorsConnection connect];
	
	_executing = [[[[[RACObserve(self, activeExecutionSignals)
		subscribeOn:self.reentrantMainThreadScheduler]
		map:^(NSArray *activeSignals) {
			return @(activeSignals.count > 0);
		}]
		distinctUntilChanged]
		replayLast]
		setNameWithFormat:@"%@ -executing", self];

	RACSignal *moreExecutionsAllowed = [RACSignal
		if:RACObserve(self, allowsConcurrentExecution)
		then:[RACSignal return:@YES]
		else:[self.executing not]];

	_enabled = [[[[[[RACSignal
		combineLatest:@[
			[enabledSignal ?: [RACSignal empty] startWith:@YES],
			moreExecutionsAllowed
		]]
		and]
		flattenMap:^(NSNumber *enabled) {
			@strongify(self);
			return [[RACSignal return:enabled] deliverOn:self.reentrantMainThreadScheduler];
		}]
		distinctUntilChanged]
		replayLast]
		setNameWithFormat:@"%@ -enabled", self];

	return self;
}

#pragma mark Execution

- (RACSignal *)execute:(id)input {
	RACReplaySubject *resultSignal = [[RACReplaySubject subject] setNameWithFormat:@"%@ -execute: %@", self, [input rac_description]];

	@weakify(self);
	[self.reentrantMainThreadScheduler schedule:^{
		NSNumber *enabled = [self.enabled first];
		if (!enabled.boolValue) {
			NSError *error = [NSError errorWithDomain:RACCommandErrorDomain code:RACCommandErrorNotEnabled userInfo:@{
				NSLocalizedDescriptionKey: NSLocalizedString(@"The command is disabled and cannot be executed", nil)
			}];

			[resultSignal sendError:error];
			return;
		}

		RACSignal *signal = self.signalBlock(input);
		NSCAssert(signal != nil, @"nil signal returned from signal block for value: %@", input);

		RACMulticastConnection *connection = [signal multicast:resultSignal];

		[[self mutableArrayValueForKey:@keypath(self.activeExecutionSignals)] addObject:connection.signal];
		[[connection.signal
			finally:^{
				@strongify(self);
				[[self mutableArrayValueForKey:@keypath(self.activeExecutionSignals)] removeObject:connection.signal];
			}]
			subscribeCompleted:^{}];

		[connection connect];
	}];

	return resultSignal;
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// Generate all KVO notifications manually to avoid the performance impact
	// of unnecessary swizzling.
	return NO;
}

@end
