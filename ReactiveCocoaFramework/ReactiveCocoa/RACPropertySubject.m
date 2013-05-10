//
//  RACPropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject+Private.h"
#import "RACBinding+Private.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACTuple.h"
#import "EXTScope.h"

@interface RACPropertySubject ()

// The signal passed to `-initWithSignal:subscriber:`. Refer to the method's
// docs for details.
@property (nonatomic, readonly, strong) RACSignal *signal;

// The subscriber passed to `-initWithSignal:subscriber:`. Refer to the method's
// docs for details.
@property (nonatomic, readonly, strong) id<RACSubscriber> subscriber;

// The signal exposed to callers. The property will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The property will behave like this
// subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@implementation RACPropertySubject

#pragma mark NSObject

- (id)init {
	RACReplaySubject *backing = [RACReplaySubject replaySubjectWithCapacity:1];
	[backing sendNext:[RACTuple tupleWithObjects:RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];
	return [self initWithSignal:backing subscriber:backing];
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
	
	_signal = signal;
	_subscriber = subscriber;
	
	@weakify(self);
	_exposedSignal = [_signal map:^(RACTuple *value) {
		return value.first;
	}];
	_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		[subscriber sendNext:[RACTuple tupleWithObjects:x, RACTupleNil.tupleNil, nil]];
	} error:^(NSError *error) {
		@strongify(self);
		NSCAssert(NO, @"Received error in RACPropertySubject %@: %@", self, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACPropertySubject %@: %@", self, error);
	} completed:nil];
	
	return self;
}

+ (instancetype)property {
	return [self subject];
}

- (RACBinding *)binding {
	return [[RACBinding alloc] initWithSignal:self.signal subscriber:self.subscriber];
}

@end
