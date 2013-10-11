//
//  RACReturnSignal.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACReturnSignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"

@interface RACReturnSignal ()

// The value to send upon subscription.
@property (nonatomic, strong, readonly) id value;

@end

@implementation RACReturnSignal

#pragma mark Lifecycle

+ (RACSignal *)return:(id)value {
	RACReturnSignal *signal = [[self alloc] init];
	signal->_value = value;

#ifdef DEBUG
	[signal setNameWithFormat:@"+return: %@", value];
#else
	signal.name = @"+return:";
#endif

	return signal;
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		[subscriber sendNext:self.value];
		[subscriber sendCompleted];
	}];
}

@end
