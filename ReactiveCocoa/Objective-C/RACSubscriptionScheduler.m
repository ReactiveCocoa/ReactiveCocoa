//
//  RACSubscriptionScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptionScheduler.h"
#import "RACScheduler+Private.h"

@interface RACSubscriptionScheduler ()

// A private background scheduler on which to subscribe if the +currentScheduler
// is unknown.
@property (nonatomic, strong, readonly) RACScheduler *backgroundScheduler;

@end

@implementation RACSubscriptionScheduler

#pragma mark Lifecycle

- (id)init {
	self = [super initWithName:@"com.ReactiveCocoa.RACScheduler.subscriptionScheduler"];
	if (self == nil) return nil;

	_backgroundScheduler = [RACScheduler scheduler];

	return self;
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	if (RACScheduler.currentScheduler == nil) return [self.backgroundScheduler schedule:block];

	block();
	return nil;
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
	RACScheduler *scheduler = RACScheduler.currentScheduler ?: self.backgroundScheduler;
	return [scheduler after:date schedule:block];
}

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
	RACScheduler *scheduler = RACScheduler.currentScheduler ?: self.backgroundScheduler;
	return [scheduler after:date repeatingEvery:interval withLeeway:leeway schedule:block];
}

@end
