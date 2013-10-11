//
//  RACEmptySignal.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACEmptySignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"

@implementation RACEmptySignal

#pragma mark Lifecycle

+ (RACSignal *)empty {
	return [[[self alloc] init] setNameWithFormat:@"+empty"];
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		[subscriber sendCompleted];
	}];
}

@end
