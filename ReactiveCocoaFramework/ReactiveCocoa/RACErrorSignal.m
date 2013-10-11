//
//  RACErrorSignal.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACErrorSignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"

@interface RACErrorSignal ()

// The error to send upon subscription.
@property (nonatomic, copy, readonly) NSError *error;

@end

@implementation RACErrorSignal

#pragma mark Lifecycle

+ (RACSignal *)error:(NSError *)error {
	RACErrorSignal *signal = [[self alloc] init];
	signal->_error = [error copy];
	return [signal setNameWithFormat:@"+error: %@", error];
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		[subscriber sendError:self.error];
	}];
}

@end
