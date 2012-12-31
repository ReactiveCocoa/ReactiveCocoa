//
//  RACProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty+Private.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACTuple.h"
#import "EXTScope.h"

@interface RACProperty ()

@property (nonatomic, readonly, strong) RACSignal *signal;
@property (nonatomic, readonly, strong) id<RACSubscriber> subscriber;
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@interface RACBinding ()

- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@property (nonatomic, readonly, strong) RACSignal *exposedSignal;
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@implementation RACProperty

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
	_exposedSignal = [_signal map:^id(RACTuple *value) {
		return value.first;
	}];
	_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		[subscriber sendNext:[RACTuple tupleWithObjects:x, RACTupleNil.tupleNil, nil]];
	} error:nil completed:nil];
	return self;
}

+ (instancetype)property {
	RACReplaySubject *backing = [RACReplaySubject replaySubjectWithCapacity:1];
	[backing sendNext:[RACTuple tupleWithObjects:RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];
	return [[self alloc] initWithSignal:backing subscriber:backing];
}

- (RACBinding *)binding {
	return [[RACBinding alloc] initWithSignal:self.signal subscriber:self.subscriber];
}

@end

@implementation RACBinding

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
	@weakify(self);
	_exposedSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [signal subscribeNext:^(RACTuple *x) {
			@strongify(self)
			if (isFirstNext) {
				isFirstNext = NO;
				[subscriber sendNext:x.first];
				return;
			}
			if (![x.second isEqual:self]) {
				[subscriber sendNext:x.first];
			}
		}];
	}];
	_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(self);
		[subscriber sendNext:[RACTuple tupleWithObjects:x ?: RACTupleNil.tupleNil, self ?: RACTupleNil.tupleNil, nil]];
	} error:nil completed:nil];
	return self;
}

- (RACDisposable *)bindTo:(RACBinding *)binding {
	RACDisposable *bindingDisposable = [binding subscribe:self];
	RACDisposable *selfDisposable = [self subscribe:binding];
	return [RACDisposable disposableWithBlock:^{
		[bindingDisposable dispose];
		[selfDisposable dispose];
	}];
}

@end
