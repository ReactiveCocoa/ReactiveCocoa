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

// The scheduler upon which to subscribe to `sourceSignal` and `results`.
//
// This must not be nil.
@property (nonatomic, strong, readonly) RACScheduler *scheduler;

// Although RACReplaySubject is deprecated for consumers, we're going to use it
// internally for the foreseeable future. We just want to expose something
// higher level.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// The results of the promised work.
@property (nonatomic, strong, readonly) RACReplaySubject *results;

#pragma clang diagnostic pop

@end

@implementation RACPromise

#pragma mark Lifecycle

- (id)initWithSignal:(RACSignal *)signal scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(signal != nil);
	NSCParameterAssert(scheduler != nil);

	self = [super init];
	if (self == nil) return nil;

	_sourceSignal = [signal subscribeOn:scheduler];
	_scheduler = scheduler;

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	_results = [[RACReplaySubject subject] setNameWithFormat:@"[%@] -promise", signal.name];
	#pragma clang diagnostic pop

	return self;
}

+ (instancetype)promiseWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != nil);

	RACSignal *signal = [[RACSignal
		createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			block(subscriber);
			return nil;
		}]
		setNameWithFormat:@"+promiseWithScheduler: %@ block:", scheduler];
	
	RACPromise *promise = [[self alloc] initWithSignal:signal scheduler:scheduler];
	promise.results.name = signal.name;
	return promise;
}

#pragma mark Starting

- (RACSignal *)start {
	BOOL shouldStart = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasStarted);
	if (shouldStart) {
		[self.sourceSignal subscribe:self.results];
	}

	return [[self.results
		subscribeOn:self.scheduler]
		setNameWithFormat:@"[%@] -start", self.results.name];
}

- (RACSignal *)deferred {
	return [[RACSignal
		defer:^{
			return [self start];
		}]
		setNameWithFormat:@"[%@] -deferred", self.results.name];
}

@end
