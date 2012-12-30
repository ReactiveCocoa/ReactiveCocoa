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
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

@end

@implementation RACBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendError:(NSError *)error {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendCompleted {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

#pragma mark API

- (RACDisposable *)bindTo:(RACBinding *)binding {
	RACDisposable *bindingDisposable = [binding subscribe:self];
	RACDisposable *selfDisposable = [self subscribe:binding];
	return [RACDisposable disposableWithBlock:^{
		[bindingDisposable dispose];
		[selfDisposable dispose];
	}];
	
}

@end
