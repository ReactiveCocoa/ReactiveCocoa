//
//  RACAction.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDynamicSignalGenerator.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriptingAssignmentTrampoline.h"

#import <libkern/OSAtomic.h>

NSString * const RACActionErrorDomain = @"RACActionErrorDomain";
const NSInteger RACActionErrorNotEnabled = 1;
NSString * const RACActionErrorKey = @"RACActionErrorKey";

@interface RACAction () {
	RACSubject *_errors;

	// Atomic backing variables for implementing `immediateEnabled` and
	// `immediateExecuting` ourselves (needed so we can also generate KVO
	// notifications ourselves).
	volatile int _immediateEnabled;
	volatile int _immediateExecuting;
}

// The generator that the receiver was initialized with.
@property (nonatomic, strong, readonly) RACSignalGenerator *generator;

// Whether the receiver is currently enabled.
//
// This property may be modified from any thread.
@property (atomic, assign) BOOL immediateEnabled;

// Whether the receiver is currently executing.
//
// This property may be modified from any thread.
@property (atomic, assign) BOOL immediateExecuting;

// Improves the performance of KVO on the receiver.
//
// See the documentation for <NSKeyValueObserving> for more information.
@property (atomic) void *observationInfo;

@end

@implementation RACAction

#pragma mark Properties

- (RACSignal *)signalWithImmediateProperty:(RACSignal *)immediate {
	NSCParameterAssert(immediate != nil);

	RACSignal *mainThreadValues = [[immediate
		skip:1]
		deliverOn:RACScheduler.mainThreadScheduler];

	return [[[immediate
		take:1]
		concat:mainThreadValues]
		distinctUntilChanged];
}

- (BOOL)immediateEnabled {
	return _immediateEnabled != 0;
}

- (void)setImmediateEnabled:(BOOL)value {
	[self willChangeValueForKey:@keypath(self.immediateEnabled)];

	if (value) {
		OSAtomicCompareAndSwapIntBarrier(0, 1, &_immediateEnabled);
	} else {
		OSAtomicCompareAndSwapIntBarrier(1, 0, &_immediateEnabled);
	}

	[self didChangeValueForKey:@keypath(self.immediateEnabled)];
}

- (BOOL)immediateExecuting {
	return _immediateExecuting != 0;
}

- (void)setImmediateExecuting:(BOOL)value {
	[self willChangeValueForKey:@keypath(self.immediateExecuting)];

	if (value) {
		OSAtomicCompareAndSwapIntBarrier(0, 1, &_immediateExecuting);
	} else {
		OSAtomicCompareAndSwapIntBarrier(1, 0, &_immediateExecuting);
	}

	[self didChangeValueForKey:@keypath(self.immediateExecuting)];
}

- (RACSignal *)enabled {
	return [[self
		signalWithImmediateProperty:RACObserve(self, immediateEnabled)]
		setNameWithFormat:@"%@ -enabled", self];
}

- (RACSignal *)executing {
	return [[self
		signalWithImmediateProperty:RACObserve(self, immediateExecuting)]
		setNameWithFormat:@"%@ -executing", self];
}

#pragma mark Lifecycle

- (instancetype)initWithEnabled:(RACSignal *)enabledSignal generator:(RACSignalGenerator *)generator {
	NSCParameterAssert(enabledSignal != nil);
	NSCParameterAssert(generator != nil);

	self = [super init];
	if (self == nil) return nil;

	_generator = generator;
	_errors = [[RACSubject subject] setNameWithFormat:@"%@ -errors", self];

	RAC(self, immediateEnabled) = [RACSignal
		combineLatest:@[
			[enabledSignal startWith:@YES],
			RACObserve(self, immediateExecuting),
		] reduce:^(NSNumber *enabled, NSNumber *executing) {
			return @(enabled.boolValue && !executing.boolValue);
		}];

	return self;
}

- (void)dealloc {
	RACSubject *errors = _errors;

	[RACScheduler.mainThreadScheduler schedule:^{
		[errors sendCompleted];
	}];
}

#pragma mark Execution

- (void)execute:(id)input {
	[[self deferred:input] subscribe:nil];
}

- (RACSignal *)deferred:(id)input {
	return [[[RACSignal
		defer:^{
			if (!self.immediateEnabled) {
				NSError *disabledError = [NSError errorWithDomain:RACActionErrorDomain code:RACActionErrorNotEnabled userInfo:@{
					NSLocalizedDescriptionKey: NSLocalizedString(@"The action is disabled and cannot be executed", nil),
					RACActionErrorKey: self
				}];

				return [RACSignal error:disabledError];
			}

			// Because `immediateExecuting` is only ever set to `YES` on the
			// main thread (per our -subscribeOn:), there's no way another
			// thread could perform the assignment below before we get to it.
			//
			// It _is_ possible for the `enabledSignal` given upon
			// initialization to send `NO` and invalidate our check above, but
			// the ordering isn't well-defined there anyways.
			self.immediateExecuting = YES;

			return [[[[self.generator
				signalWithValue:input]
				deliverOn:RACScheduler.mainThreadScheduler]
				doError:^(NSError *error) {
					[_errors sendNext:error];
				}]
				doDisposed:^{
					// It's okay to flip this to `NO` on a background thread (if
					// that's where we happen to be disposed), since it won't
					// _prevent_ other threads from doing anything, but this
					// must only be set to `YES` on the main thread.
					self.immediateExecuting = NO;
				}];
		}]
		subscribeOn:RACScheduler.mainThreadScheduler]
		setNameWithFormat:@"%@ -deferred: %@", self, [input rac_description]];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// Generate all KVO notifications manually to avoid the performance impact
	// of unnecessary swizzling.
	return NO;
}

@end

@implementation RACSignalGenerator (RACActionAdditions)

- (RACAction *)action {
	return [self actionEnabledIf:[RACSignal empty]];
}

- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal {
	return [[RACAction alloc] initWithEnabled:enabledSignal generator:self];
}

@end

@implementation RACSignal (RACActionAdditions)

- (RACAction *)action {
	return [self actionEnabledIf:[RACSignal empty]];
}

- (RACAction *)actionEnabledIf:(RACSignal *)enabledSignal {
	RACSignalGenerator *generator = [RACDynamicSignalGenerator generatorWithBlock:^(id _) {
		return self;
	}];

	return [[RACAction alloc] initWithEnabled:enabledSignal generator:generator];
}

@end
