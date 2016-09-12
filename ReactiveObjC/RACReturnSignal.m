//
//  RACReturnSignal.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACReturnSignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"
#import "RACUnit.h"

@interface RACReturnSignal ()

// The value to send upon subscription.
@property (nonatomic, strong, readonly) id value;

@end

@implementation RACReturnSignal

#pragma mark Properties

// Only allow this signal's name to be customized in DEBUG, since it's
// potentially a singleton in release builds (see +return:).
- (void)setName:(NSString *)name {
#ifdef DEBUG
	[super setName:name];
#endif
}

- (NSString *)name {
#ifdef DEBUG
	return super.name;
#else
	return @"+return:";
#endif
}

#pragma mark Lifecycle

+ (RACSignal *)return:(id)value {
#ifndef DEBUG
	// In release builds, use singletons for two very common cases.
	if (value == RACUnit.defaultUnit) {
		static RACReturnSignal *unitSingleton;
		static dispatch_once_t unitPred;

		dispatch_once(&unitPred, ^{
			unitSingleton = [[self alloc] init];
			unitSingleton->_value = RACUnit.defaultUnit;
		});

		return unitSingleton;
	} else if (value == nil) {
		static RACReturnSignal *nilSingleton;
		static dispatch_once_t nilPred;

		dispatch_once(&nilPred, ^{
			nilSingleton = [[self alloc] init];
			nilSingleton->_value = nil;
		});

		return nilSingleton;
	}
#endif

	RACReturnSignal *signal = [[self alloc] init];
	signal->_value = value;

#ifdef DEBUG
	[signal setNameWithFormat:@"+return: %@", value];
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
