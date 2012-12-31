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
			if ([lazyProperty.latestValue isEqual:startingValue()]) {
				lazyProperty.latestValue = pendingDefaultValue();
				RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
				[compoundDisposable addDisposable:[start subscribeNext:^(id x) {
					@strongify(lazyProperty);
					[compoundDisposable dispose];
					@synchronized(lazyProperty) {
						if (![lazyProperty.latestValue isEqual:pendingDefaultValue()]) return;
						lazyProperty.latestValue = x;
						[subscriberSubject sendNext:[RACTuple tupleWithObjects:x ?: RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];
					}
				}]];
			} else if (![lazyProperty.latestValue isEqual:pendingDefaultValue()]) {
				[subscriber sendNext:lazyProperty.latestValue];
			}
			return [subscriberSubject subscribe:subscriber];
		}
	} copy];
	[subscriberSubject subscribeNext:^(id x) {
		@strongify(lazyProperty);
		@synchronized(lazyProperty) {
			lazyProperty.latestValue = x;
		}
	}];
	lazyProperty->_latestValue = startingValue();
	return lazyProperty;
}

- (RACSignal *)nonLazyValues {
	return self.nonLazyValuesSignal;
}

@end
