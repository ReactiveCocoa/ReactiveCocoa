//
//  RACPromise.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPromise.h"
#import "RACPromise+Private.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import <libkern/OSAtomic.h>

@interface RACPromise () {
	// When connecting, a caller should attempt to atomically swap the value of this
	// from `0` to `1`.
	//
	// If the swap is successful the caller is responsible for subscribing
	// `results` to `sourceSignal`.
	//
	// If the swap is unsuccessful it means that `sourceSignal` has already been
	// subscribed to and the caller has no action to take.
	int32_t volatile _hasStarted;
}

// The underlying signal, which must be subscribed to only once.
@property (nonatomic, strong, readonly) RACSignal *sourceSignal;

// The results of the promised work.
@property (nonatomic, strong, readonly) RACReplaySubject *results;

@end

@implementation RACPromise

#pragma mark Lifecycle

- (id)initWithSignal:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	self = [super init];
	if (self == nil) return nil;

	_sourceSignal = signal;
	_results = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -promise", signal.name];

	return self;
}

+ (instancetype)promiseWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != nil);

	RACSignal *signal = [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			return [scheduler schedule:^{
				block(subscriber);
			}];
		}]
		setNameWithFormat:@"+promiseWithScheduler: %@ block:", scheduler];
	
	RACPromise *promise = [[self alloc] initWithSignal:signal];
	promise.results.name = signal.name;
	return promise;
}

#pragma mark Starting

- (RACSignal *)start {
	BOOL shouldStart = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasStarted);
	if (shouldStart) {
		[self.sourceSignal subscribe:self.results];
	}

	return self.results;
}

- (RACSignal *)autostart {
	return [[RACSignal
		defer:^{
			return [self start];
		}]
		setNameWithFormat:@"[%@] -autostart", self.results.name];
}

@end
