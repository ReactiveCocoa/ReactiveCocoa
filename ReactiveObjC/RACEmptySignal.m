//
//  RACEmptySignal.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACEmptySignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"

@implementation RACEmptySignal

#pragma mark Properties

// Only allow this signal's name to be customized in DEBUG, since it's
// a singleton in release builds (see +empty).
- (void)setName:(NSString *)name {
#ifdef DEBUG
	[super setName:name];
#endif
}

- (NSString *)name {
#ifdef DEBUG
	return super.name;
#else
	return @"+empty";
#endif
}

#pragma mark Lifecycle

+ (RACSignal *)empty {
#ifdef DEBUG
	// Create multiple instances of this class in DEBUG so users can set custom
	// names on each.
	return [[[self alloc] init] setNameWithFormat:@"+empty"];
#else
	static id singleton;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		singleton = [[self alloc] init];
	});

	return singleton;
#endif
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		[subscriber sendCompleted];
	}];
}

@end
