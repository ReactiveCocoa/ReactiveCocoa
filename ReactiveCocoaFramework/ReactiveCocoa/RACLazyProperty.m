//
//  RACLazyProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACLazyProperty.h"
#import "RACProperty+Private.h"
#import "RACSignal+Private.h"
#import "EXTScope.h"

static id startingValue(void) {
	static id startingValue = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    startingValue = [[NSObject alloc] init];
	});
	return startingValue;
}

static id pendingDefaultValue(void) {
	static id pendingDefaultValue = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    pendingDefaultValue = [[NSObject alloc] init];
	});
	return pendingDefaultValue;
}

@interface RACLazyProperty ()

@property (nonatomic, strong) RACTuple *latestValue;
@property (nonatomic) BOOL latestValueIsDefaultValue;
@property (nonatomic, readonly, strong) RACSignal *nonLazyValuesSignal;

@end

@implementation RACLazyProperty

+ (instancetype)lazyPropertyWithStart:(RACSignal *)start {
	RACLazyProperty *lazyProperty = nil;
	RACSubject *subscriberSubject = [RACSubject subject];
	RACSignal *signal = [[RACSignal alloc] init];
	lazyProperty = [[self alloc] initWithSignal:signal subscriber:subscriberSubject];
	if (lazyProperty == nil) return nil;
	@weakify(lazyProperty);
	signal.didSubscribe = [^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(lazyProperty);
		@synchronized(lazyProperty) {
			RACDisposable *disposable = [subscriberSubject subscribe:subscriber];
			if ([lazyProperty.latestValue isEqual:startingValue()]) {
				lazyProperty.latestValue = pendingDefaultValue();
				[[start take:1] subscribeNext:^(id x) {
					@strongify(lazyProperty);
					@synchronized(lazyProperty) {
						if (![lazyProperty.latestValue isEqual:pendingDefaultValue()]) return;
						RACTuple *latestValue = [RACTuple tupleWithObjects:x ?: RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil];
						lazyProperty.latestValue = latestValue;
						[subscriberSubject sendNext:latestValue];
					}
				}];
			} else if (![lazyProperty.latestValue isEqual:pendingDefaultValue()]) {
				[subscriber sendNext:lazyProperty.latestValue];
			}
			return disposable;
		}
	} copy];
	[subscriberSubject subscribeNext:^(id x) {
		@strongify(lazyProperty);
		@synchronized(lazyProperty) {
			lazyProperty.latestValue = x;
		}
	}];
	lazyProperty->_nonLazyValuesSignal = [subscriberSubject filter:^BOOL(id value) {
		@strongify(lazyProperty);
		return !lazyProperty.latestValueIsDefaultValue;
	}];
	[[subscriberSubject take:1] subscribeNext:^(id x) {
		@strongify(lazyProperty);
		@synchronized(lazyProperty) {
			lazyProperty.latestValueIsDefaultValue = NO;
		}
	}];
	lazyProperty->_latestValue = startingValue();
	lazyProperty->_latestValueIsDefaultValue = YES;
	return lazyProperty;
}

- (RACSignal *)nonLazyValues {
	return self.nonLazyValuesSignal;
}

@end
