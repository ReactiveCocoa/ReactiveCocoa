//
//  RACProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACTuple.h"
#import "EXTScope.h"

@interface RACProperty ()

@property (nonatomic, readonly, strong) RACReplaySubject *backing;
@property (nonatomic, readonly, strong) RACSignal *signal;
@property (nonatomic, readonly, strong) id<RACSubscriber> subscriber;

@end

@interface RACBinding ()

+ (instancetype)bindingWithBacking:(RACSubject *)backing;

@property (nonatomic, readonly, strong) RACSubject *backing;
@property (nonatomic, readonly, strong) RACSignal *signal;
@property (nonatomic, readonly, strong) id<RACSubscriber> subscriber;

@end

@implementation RACProperty

#pragma mark NSObject

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	_backing = [RACReplaySubject replaySubjectWithCapacity:1];
	[_backing sendNext:[RACTuple tupleWithObjects:RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];
	@weakify(self);
	_signal = [_backing map:^id(RACTuple *value) {
		return value.first;
	}];
	_subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(self);
		[self.backing sendNext:[RACTuple tupleWithObjects:x, RACTupleNil.tupleNil, nil]];
	} error:nil completed:nil];
	return self;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.signal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.subscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.subscriber sendError:error];
}

- (void)sendCompleted {
	[self.subscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.subscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)property {
	return [[self alloc] init];
}

- (RACBinding *)binding {
	return [RACBinding bindingWithBacking:self.backing];
}

@end

@implementation RACBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.signal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.subscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.subscriber sendError:error];
}

- (void)sendCompleted {
	[self.subscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.subscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)bindingWithBacking:(RACSubject *)backing {
	RACBinding *binding = [[self alloc] init];
	if (binding == nil) return nil;
	binding->_backing = backing;
	@weakify(binding);
	binding->_signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [backing subscribeNext:^(RACTuple *x) {
			@strongify(binding)
			if (isFirstNext) {
				isFirstNext = NO;
				[subscriber sendNext:x.first];
				return;
			}
			if (![x.second isEqual:binding]) {
				[subscriber sendNext:x.first];
			}
		}];
	}];
	
	
	[[backing filter:^BOOL(RACTuple *value) {
		@strongify(binding);
		return ![value.second isEqual:binding];
	}] map:^id(RACTuple *value) {
		return value.first;
	}];
	binding->_subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);
		[binding.backing sendNext:[RACTuple tupleWithObjects:x ?: RACTupleNil.tupleNil, binding ?: RACTupleNil.tupleNil, nil]];
	} error:nil completed:nil];
	return binding;
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
