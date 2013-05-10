//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "EXTScope.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriptingAssignmentTrampoline.h"
#import <libkern/OSAtomic.h>

@interface RACCommand () {
	RACSubject *_errors;

	// Indicates how many -execute: calls and signals are currently in-flight.
	//
	// This variable can be read at any time, but must be modified through
	// -incrementItemsInFlight and -decrementItemsInFlight.
	volatile int32_t _itemsInFlight;
}

@property (atomic, readwrite) BOOL canExecute;

// A signal of the values passed to -execute:.
//
// Subscriptions to the receiver will actually be redirected to this subject.
@property (nonatomic, strong, readonly) RACSubject *values;

// Improves the performance of KVO on the receiver.
//
// See the documentation for <NSKeyValueObserving> for more information.
@property (atomic) void *observationInfo;

// Increments _itemsInFlight atomically and generates a KVO notification for the
// `executing` property.
- (void)incrementItemsInFlight;

// Decrements _itemsInFlight atomically and generates a KVO notification for the
// `executing` property.
- (void)decrementItemsInFlight;

@end

@implementation RACCommand

#pragma mark Properties

- (BOOL)isExecuting {
	return _itemsInFlight > 0;
}

- (void)incrementItemsInFlight {
	[self willChangeValueForKey:@keypath(self.executing)];
	OSAtomicIncrement32Barrier(&_itemsInFlight);
	[self didChangeValueForKey:@keypath(self.executing)];
}

- (void)decrementItemsInFlight {
	[self willChangeValueForKey:@keypath(self.executing)];

	int32_t newValue __attribute__((unused)) = OSAtomicDecrement32Barrier(&_itemsInFlight);
	NSCAssert(newValue >= 0, @"Unbalanced decrement of _itemsInFlight");

	[self didChangeValueForKey:@keypath(self.executing)];
}

- (NSString *)name {
	return self.values.name;
}

- (void)setName:(NSString *)name {
	self.values.name = name;
}

#pragma mark Lifecycle

- (void)dealloc {
	[_values sendCompleted];
	[_errors sendCompleted];
}

+ (instancetype)command {
	return [self commandWithCanExecuteSignal:nil];
}

+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal {
	return [[self alloc] initWithCanExecuteSignal:canExecuteSignal];
}

- (id)init {
	return [self initWithCanExecuteSignal:nil];
}

- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal {
	self = [super init];
	if (self == nil) return nil;

	_values = [RACSubject subject];
	_errors = [RACSubject subject];

	RAC(self.canExecute) = [RACSignal
		combineLatest:@[
			[canExecuteSignal startWith:@YES] ?: [RACSignal return:@YES],
			RACAbleWithStart(self.allowsConcurrentExecution),
			RACAbleWithStart(self.executing)
		] reduce:^(NSNumber *canExecute, NSNumber *allowsConcurrency, NSNumber *executing) {
			BOOL blocking = !allowsConcurrency.boolValue && executing.boolValue;
			return @(canExecute.boolValue && !blocking);
		}];
	
	return self;
}

#pragma mark Execution

- (RACSignal *)addSignalBlock:(RACSignal * (^)(id value))signalBlock {
	NSCParameterAssert(signalBlock != nil);

	@weakify(self);

	return [[[[self.values
		doNext:^(id _) {
			@strongify(self);
			[self incrementItemsInFlight];
		}]
		map:^(id value) {
			RACSignal *signal = signalBlock(value);
			NSCAssert(signal != nil, @"signalBlock returned a nil signal");

			return [[[signal
				doError:^(NSError *error) {
					[RACScheduler.mainThreadScheduler schedule:^{
						@strongify(self);
						if (self != nil) [self->_errors sendNext:error];
					}];
				}]
				finally:^{
					@strongify(self);
					[self decrementItemsInFlight];
				}]
				replay];
		}]
		replayLast]
		setNameWithFormat:@"[%@] -addSignalBlock:", self.name];
}

- (BOOL)execute:(id)value {
	@synchronized (self) {
		// Because itemsInFlight informs canExecute, we need to ensure that the
		// latter is tested and set atomically to avoid race conditions. This is
		// only necessary for incrementing, not decrementing.
		if (!self.canExecute) return NO;
		[self incrementItemsInFlight];
	}
	
	[self.values sendNext:value];
	[self decrementItemsInFlight];

	return YES;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.values subscribe:subscriber];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// This key path is notified manually when _itemsInFlight is modified.
	if ([key isEqualToString:@keypath(RACCommand.new, executing)]) return NO;

	return [super automaticallyNotifiesObserversForKey:key];
}

@end

@implementation RACCommand (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (void)sendNext:(id)value {
	[self.values sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.values sendError:error];
}

- (void)sendCompleted {
	[self.values sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.values didSubscribeWithDisposable:disposable];
}

+ (instancetype)subject {
	return [self command];
}

#pragma clang diagnostic pop

@end
