//
//  RACStaticSignal.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACStaticSignal.h"
#import "RACScheduler+Private.h"

@interface RACStaticSignal ()
@property (nonatomic, copy, readonly) void (^subscriptionBlock)(id<RACSubscriber>);
@end

@implementation RACStaticSignal

#pragma mark Lifecycle

- (instancetype)initWithSubscriptionBlock:(void (^)(id<RACSubscriber> subscriber))block {
	self = [super init];
	if (self == nil) return nil;

	_subscriptionBlock = [block copy];

	return self;
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		self.subscriptionBlock(subscriber);
	}];
}

@end
