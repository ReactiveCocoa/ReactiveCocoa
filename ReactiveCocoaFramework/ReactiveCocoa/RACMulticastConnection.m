//
//  RACMulticastConnection.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACMulticastConnection.h"
#import "RACMulticastConnection+Private.h"
#import "RACDisposable.h"
#import "RACSubject.h"
#import "RACSignal+Private.h"

@interface RACMulticastConnection () {
	RACSubject *_signal;
}

@property (nonatomic, readonly, strong) RACSignal *sourceSignal;
@property (strong) RACDisposable *disposable;

// Should only be used while synchronized on self.
@property (nonatomic, assign) BOOL hasConnected;
@end

@implementation RACMulticastConnection

#pragma mark Lifecycle

- (id)initWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject {
	NSCParameterAssert(source != nil);
	NSCParameterAssert(subject != nil);

	self = [super init];
	if (self == nil) return nil;

	_sourceSignal = source;
	_signal = subject;
	
	return self;
}

#pragma mark Connecting

- (RACDisposable *)connect {
	BOOL shouldConnect = NO;
	@synchronized(self) {
		if (!self.hasConnected) {
			shouldConnect = YES;
			self.hasConnected = YES;
		}
	}

	if (shouldConnect) {
		self.disposable = [self.sourceSignal subscribe:_signal];
	}

	return self.disposable;
}

- (RACSignal *)autoconnect {
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACDisposable *subscriptionDisposable = [self.signal subscribe:subscriber];
		[self connect];

		return [RACDisposable disposableWithBlock:^{
			[subscriptionDisposable dispose];

			if (self.signal.subscriberCount < 1) {
				[self.disposable dispose];
			}
		}];
	}] setNameWithFormat:@"[%@] -autoconnect", self.signal.name];
}

@end
