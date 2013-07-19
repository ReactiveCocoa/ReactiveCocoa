//
//  RACPropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject+Private.h"
#import "EXTScope.h"
#import "RACBinding+Private.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSubscriber+Private.h"
#import "RACTuple.h"

@interface RACPropertySubject ()

// A subject ot tuples where the first element is a value of the property and
// the second element is the binding the value was sent to, or nil if the value
// was sent to the property directly.
@property (nonatomic, readonly, strong) RACReplaySubject *backing;

// The signal exposed to callers. The property will behave like this signal
// towards its subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The property will behave like this
// subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@implementation RACPropertySubject

#pragma mark NSObject

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	@weakify(self);

	RACReplaySubject *backing = [RACReplaySubject replaySubjectWithCapacity:1];
	[backing sendNext:[RACTuple tupleWithObjects:RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];

	_backing = backing;

	_exposedSignal = [backing map:^(RACTuple *value) {
		return value.first;
	}];

	_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		[backing sendNext:RACTuplePack(x, RACTupleNil.tupleNil)];
	} error:^(NSError *error) {
		@strongify(self);
		NSCAssert(NO, @"Received error in RACPropertySubject %@: %@", self, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACPropertySubject %@: %@", self, error);
	} completed:^{
		[backing sendCompleted];
	}];

	return self;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.exposedSignal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.exposedSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.exposedSubscriber sendError:error];
}

- (void)sendCompleted {
	[self.exposedSubscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.exposedSubscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber {
	self = [super init];
	if (self == nil) return nil;
	
	_exposedSignal = signal;
	_exposedSubscriber = subscriber;
		
	return self;
}

+ (instancetype)property {
	return [self subject];
}

- (RACBinding *)binding {
	RACReplaySubject *backing = self.backing;
	RACBinding *binding = [RACBinding alloc];
	@weakify(binding);

	RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [backing subscribeNext:^(RACTuple *x) {
			@strongify(binding);

			if (isFirstNext || ![x.second isEqual:binding]) {
				isFirstNext = NO;
				[subscriber sendNext:x.first];
			}
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];

	id<RACSubscriber> subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);

		[backing sendNext:RACTuplePack(x, binding)];
	} error:^(NSError *error) {
		@strongify(binding);

		NSCAssert(NO, @"Received error in RACBinding %@: %@", binding, error);
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACBinding %@: %@", binding, error);

		[backing sendError:error];
	} completed:^{
		[backing sendCompleted];
	}];

	return [binding initWithSignal:signal subscriber:subscriber];
}

@end
