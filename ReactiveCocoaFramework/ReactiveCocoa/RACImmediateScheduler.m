//
//  RACImmediateScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACImmediateScheduler.h"
#import "RACScheduler+Private.h"

@implementation RACImmediateScheduler

#pragma mark Lifecycle

- (id)init {
	return [super initWithName:@"com.ReactiveCocoa.RACScheduler.immediateScheduler"];
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSCParameterAssert(block != NULL);

	block();
	return nil;
}

- (RACDisposable *)after:(NSDate *)date schedule:(void (^)(void))block {
	NSCParameterAssert(date != nil);
	NSCParameterAssert(block != NULL);

	[NSThread sleepUntilDate:date];
	block();

	return nil;
}

- (RACDisposable *)after:(NSDate *)date repeatingEvery:(NSTimeInterval)interval withLeeway:(NSTimeInterval)leeway schedule:(void (^)(void))block {
	NSCAssert(NO, @"+[RACScheduler immediateScheduler] does not support %@.", NSStringFromSelector(_cmd));
	return nil;
}

@end
