//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACTuple.h"
#import "EXTScope.h"

@interface RACBinding ()

// The signal exposed to callers. The property will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The property will behave like this
// subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

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
	_exposedSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [signal subscribeNext:^(RACTuple *x) {
			@strongify(self);
			if (isFirstNext || ![x.second isEqual:self]) {
				isFirstNext = NO;
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
	RACDisposable *selfDisposable = [[self skip:1] subscribe:binding];
	return [RACDisposable disposableWithBlock:^{
		[bindingDisposable dispose];
		[selfDisposable dispose];
	}];
}

@end
