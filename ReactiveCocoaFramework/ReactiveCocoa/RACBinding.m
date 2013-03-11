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

- (void)didUpdateWithNewValue:(id)value {
	[self.exposedSubscriber didUpdateWithNewValue:value];
}

- (void)didReceiveErrorWithError:(NSError *)error {
	[self.exposedSubscriber didReceiveErrorWithError:error];
}

- (void)terminateSubscription {
	[self.exposedSubscriber terminateSubscription];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.exposedSubscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber {
	self = [super init];
	if (self == nil) return nil;
	
	@weakify(self);
	_exposedSignal = [RACSignal signalWithSubscriptionHandler:^(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [signal observeWithUpdateHandler:^(RACTuple *x) {
			@strongify(self);
			if (isFirstNext || ![x.second isEqual:self]) {
				isFirstNext = NO;
				[subscriber didUpdateWithNewValue:x.first];
			}
		}];
	}];
	_exposedSubscriber = [RACSubscriber subscriberWithUpdateHandler:^(id x) {
		@strongify(self);
		[subscriber didUpdateWithNewValue:[RACTuple tupleWithObjects:x ?: RACTupleNil.tupleNil, self ?: RACTupleNil.tupleNil, nil]];
	} errorHandler:nil completionHandler:nil];
	
	return self;
}

- (RACDisposable *)disposableWithBinding:(RACBinding *)binding {
	RACDisposable *bindingDisposable = [binding subscribe:self];
	RACDisposable *selfDisposable = [[self streamByRemovingObjectsBeforeIndex:1] subscribe:binding];
	return [RACDisposable disposableWithBlock:^{
		[bindingDisposable dispose];
		[selfDisposable dispose];
	}];
}

@end
