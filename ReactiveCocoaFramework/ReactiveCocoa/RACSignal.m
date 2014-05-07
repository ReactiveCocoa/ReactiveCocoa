//
//  RACSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACDynamicSignal.h"
#import "RACEmptySignal.h"
#import "RACErrorSignal.h"
#import "RACLiveSubscriber.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACReturnSignal.h"
#import "RACScheduler.h"
#import "RACSerialDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACTuple.h"

@implementation RACSignal

#pragma mark Lifecycle

+ (RACSignal *)create:(void (^)(id<RACSubscriber> subscriber))didSubscribe {
	return [RACDynamicSignal create:didSubscribe];
}

+ (RACSignal *)error:(NSError *)error {
	return [RACErrorSignal error:error];
}

+ (RACSignal *)never {
	return [[self create:^(id<RACSubscriber> subscriber) {
		// Do nothing. This will cause the signal to live indefinitely unless
		// interrupted in some way.
	}] setNameWithFormat:@"+never"];
}

+ (RACSignal *)empty {
	return [RACEmptySignal empty];
}

+ (RACSignal *)return:(id)value {
	return [RACReturnSignal return:value];
}

#pragma mark Subscription

- (void)attachSubscriber:(RACLiveSubscriber *)subscriber {
	NSCAssert(NO, @"This method must be overridden by subclasses.");
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> name: %@", self.class, self, self.name];
}

@end

@implementation RACSignal (Debugging)

@dynamic name;

- (instancetype)setNameWithFormat:(NSString *)format, ... {
	// This implementation is copied from RACStream because lolvarargs.
	//
	// Once RACStream is actually removed, this will be the sole implementation.

#ifdef DEBUG
	NSCParameterAssert(format != nil);

	va_list args;
	va_start(args, format);

	NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);

	self.name = str;
#endif
	
	return self;
}

- (RACSignal *)logAll {
	return [[[self logNext] logError] logCompleted];
}

- (RACSignal *)logNext {
	return [[self doNext:^(id x) {
		NSLog(@"%@ next: %@", self, x);
	}] setNameWithFormat:@"%@", self.name];
}

- (RACSignal *)logError {
	return [[self doError:^(NSError *error) {
		NSLog(@"%@ error: %@", self, error);
	}] setNameWithFormat:@"%@", self.name];
}

- (RACSignal *)logCompleted {
	return [[self doCompleted:^{
		NSLog(@"%@ completed", self);
	}] setNameWithFormat:@"%@", self.name];
}

@end

@implementation RACSignal (Testing)

static const NSTimeInterval RACSignalAsynchronousWaitTimeout = 10;

- (id)asynchronousFirstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
	NSCAssert([NSThread isMainThread], @"%s should only be used from the main thread", __func__);

	__block id result = defaultValue;
	__block BOOL done = NO;

	// Ensures that we don't pass values across thread boundaries by reference.
	__block NSError *localError;
	__block BOOL localSuccess = YES;

	[[[[self
		take:1]
		timeout:RACSignalAsynchronousWaitTimeout onScheduler:[RACScheduler scheduler]]
		deliverOn:RACScheduler.mainThreadScheduler]
		subscribeNext:^(id x) {
			result = x;
			done = YES;
		} error:^(NSError *e) {
			if (!done) {
				localSuccess = NO;
				localError = e;
				done = YES;
			}
		} completed:^{
			done = YES;
		}];
	
	do {
		[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	} while (!done);

	if (success != NULL) *success = localSuccess;
	if (error != NULL) *error = localError;

	return result;
}

- (BOOL)asynchronouslyWaitUntilCompleted:(NSError **)error {
	BOOL success = NO;
	[[self ignoreValues] asynchronousFirstOrDefault:nil success:&success error:error];
	return success;
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation RACSignal (Deprecated)

+ (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
	return [self create:^(id<RACSubscriber> subscriber) {
		[subscriber.disposable addDisposable:didSubscribe(subscriber)];
	}];
}

+ (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != NULL);

	RACSignal *signal = [self startLazilyWithScheduler:scheduler block:block];
	// Subscribe to force the lazy signal to call its block.
	[[signal publish] connect];
	return [signal setNameWithFormat:@"+startEagerlyWithScheduler:%@ block:", scheduler];
}

+ (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
	NSCParameterAssert(scheduler != nil);
	NSCParameterAssert(block != NULL);

	RACMulticastConnection *connection = [[RACSignal
		createSignal:^ id (id<RACSubscriber> subscriber) {
			block(subscriber);
			return nil;
		}]
		multicast:[RACReplaySubject subject]];
	
	return [[[RACSignal
		createSignal:^ id (id<RACSubscriber> subscriber) {
			[connection.signal subscribe:subscriber];
			[connection connect];
			return nil;
		}]
		subscribeOn:scheduler]
		setNameWithFormat:@"+startLazilyWithScheduler:%@ block:", scheduler];
}

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACLiveSubscriber *liveSubscriber;
	if (subscriber == nil) {
		liveSubscriber = [RACLiveSubscriber subscriberWithNext:nil error:nil completed:nil];
	} else {
		liveSubscriber = [RACLiveSubscriber subscriberForwardingToSubscriber:subscriber];
	}

	liveSubscriber.signal = self;

	[self attachSubscriber:liveSubscriber];
	return liveSubscriber.disposable;
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock {
	return [self subscribeNext:nextBlock error:nil completed:nil];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock {
	return [self subscribeNext:nextBlock error:nil completed:completedBlock];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	RACLiveSubscriber *subscriber = [RACLiveSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	subscriber.signal = self;

	[self attachSubscriber:subscriber];
	return subscriber.disposable;
}

- (RACDisposable *)subscribeError:(void (^)(NSError *error))errorBlock {
	return [self subscribeNext:nil error:errorBlock completed:nil];
}

- (RACDisposable *)subscribeCompleted:(void (^)(void))completedBlock {
	return [self subscribeNext:nil error:nil completed:completedBlock];
}

- (RACDisposable *)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock {
	return [self subscribeNext:nextBlock error:errorBlock completed:nil];
}

- (RACDisposable *)subscribeError:(void (^)(NSError *))errorBlock completed:(void (^)(void))completedBlock {
	return [self subscribeNext:nil error:errorBlock completed:completedBlock];
}

- (void)subscribeSavingDisposable:(void (^)(RACDisposable *))saveDisposableBlock next:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock {
	NSCParameterAssert(saveDisposableBlock != nil);

	RACLiveSubscriber *subscriber = [RACLiveSubscriber subscriberWithNext:nextBlock error:errorBlock completed:completedBlock];
	subscriber.signal = self;

	saveDisposableBlock(subscriber.disposable);
	[self attachSubscriber:subscriber];
}

@end

#pragma clang diagnostic pop
