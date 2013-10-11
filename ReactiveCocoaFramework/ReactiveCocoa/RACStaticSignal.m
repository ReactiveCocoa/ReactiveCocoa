//
//  RACStaticSignal.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACStaticSignal.h"
#import "RACScheduler+Private.h"
#import "RACSubscriber.h"
#import "RACUnit.h"

@interface RACStaticSignal ()
#ifndef DEBUG
@property (nonatomic, copy) NSString *singletonName;
#endif
@property (nonatomic, copy, readonly) void (^subscriptionBlock)(id<RACSubscriber>);
@end

@implementation RACStaticSignal

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
	return self.singletonName;
#endif
}

#pragma mark Lifecycle

- (instancetype)initWithSubscriptionBlock:(void (^)(id<RACSubscriber> subscriber))block {
	self = [super init];
	if (self == nil) return nil;

	_subscriptionBlock = [block copy];

	return self;
}

+ (RACSignal *)empty {
	void (^empty)(id<RACSubscriber>) = ^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	};

#ifdef DEBUG
	// Create multiple instances of this class in DEBUG so users can set custom
	// names on each.
	return [[[self alloc] initWithSubscriptionBlock:empty] setNameWithFormat:@"+empty"];
#else
	static id singleton;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		singleton = [[self alloc] initWithSubscriptionBlock:empty];
		singleton.singletonName = @"+empty";
	});

	return singleton;
#endif
}

+ (RACSignal *)error:(NSError *)error {
	RACStaticSignal *signal = [[self alloc] initWithSubscriptionBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];

#ifdef DEBUG
	[signal setNameWithFormat:@"+error: %@", error];
#else
	signal.singletonName = @"+error:";
#endif

	return signal;
}

+ (RACSignal *)return:(id)value {
#ifndef DEBUG
	// In release builds, use singletons for two very common cases.
	if (value == RACUnit.defaultUnit) {
		static RACStaticSignal *unitSingleton;
		static dispatch_once_t unitPred;

		dispatch_once(&unitPred, ^{
			unitSingleton = [[self alloc] initWithSubscriptionBlock:^(id<RACSubscriber> subscriber) {
				[subscriber sendNext:RACUnit.defaultUnit];
				[subscriber sendCompleted];
			}];
			unitSingleton.singletonName = @"+return: RACUnit";
		});

		return unitSingleton;
	} else if (value == nil) {
		static RACStaticSignal *nilSingleton;
		static dispatch_once_t nilPred;

		dispatch_once(&nilPred, ^{
			nilSingleton = [[self alloc] initWithSubscriptionBlock:^(id<RACSubscriber> subscriber) {
				[subscriber sendNext:nil];
				[subscriber sendCompleted];
			}];
			nilSingleton.singletonName = @"+return: nil";
		});

		return nilSingleton;
	}
#endif

	RACStaticSignal *signal = [[self alloc] initWithSubscriptionBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
		[subscriber sendCompleted];
	}];

#ifdef DEBUG
	[signal setNameWithFormat:@"+return: %@", value];
#else
	signal.singletonName = @"+return:";
#endif

	return signal;
}

+ (RACSignal *)never {
	void (^never)(id<RACSubscriber>) = ^(id<RACSubscriber> subscriber) {};

#ifdef DEBUG
	// Create multiple instances of this class in DEBUG so users can set custom
	// names on each.
	return [[[self alloc] initWithSubscriptionBlock:never] setNameWithFormat:@"+never"];
#else
	static id singleton;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		singleton = [[self alloc] initWithSubscriptionBlock:never];
		singleton.singletonName = @"+never";
	});

	return singleton;
#endif
}

+ (RACSignal *)defer:(RACSignal * (^)(void))block {
	NSCParameterAssert(block != nil);

	RACStaticSignal *signal = [[self alloc] initWithSubscriptionBlock:^(id<RACSubscriber> subscriber) {
		[block() subscribe:subscriber];
	}];

#ifdef DEBUG
	[signal setNameWithFormat:@"+defer:"];
#else
	signal.singletonName = @"+defer:";
#endif

	return signal;
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	return [RACScheduler.subscriptionScheduler schedule:^{
		self.subscriptionBlock(subscriber);
	}];
}

@end
