//
//  RACDynamicSignal.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignal.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
#import "RACLiveSubscriber.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"
#import <libkern/OSAtomic.h>

@interface RACDynamicSignal ()

// The block to invoke for each subscription.
@property (nonatomic, copy, readonly) void (^didSubscribe)(id<RACSubscriber> subscriber);

@end

@implementation RACDynamicSignal

#pragma mark Lifecycle

+ (RACSignal *)create:(void (^)(id<RACSubscriber>))didSubscribe {
	RACDynamicSignal *signal = [[self alloc] init];
	signal->_didSubscribe = [didSubscribe copy];
	return [signal setNameWithFormat:@"+createSignal:"];
}

#pragma mark Managing Subscribers

- (void)attachSubscriber:(RACLiveSubscriber *)subscriber {
	NSCParameterAssert(subscriber != nil);

	if (self.didSubscribe != NULL) {
		self.didSubscribe(subscriber);
	}
}

@end
