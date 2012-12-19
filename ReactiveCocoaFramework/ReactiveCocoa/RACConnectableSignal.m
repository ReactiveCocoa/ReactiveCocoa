//
//  RACConnectableSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSignal.h"
#import "RACConnectableSignal+Private.h"
#import "RACSignal+Private.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "RACDisposable.h"

@interface RACConnectableSignal ()
@property (nonatomic, strong) RACSignal *sourceSignal;
@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACDisposable *disposable;
@end

@implementation RACConnectableSignal

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.subject subscribe:subscriber];
}

#pragma mark API

+ (instancetype)connectableSignalWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject {
	RACConnectableSignal *signal = [[self alloc] init];
	signal.sourceSignal = source;
	signal.subject = subject;
	return signal;
}

- (RACDisposable *)connect {
	@synchronized(self) {
		if (self.disposable == nil) {
			self.disposable = [self.sourceSignal subscribe:self.subject];
		}
		
		return self.disposable;
	}
}

- (RACSignal *)autoconnect {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACDisposable *subscriptionDisposable = [self subscribe:subscriber];

		[self connect];
		
		return [RACDisposable disposableWithBlock:^{
			[subscriptionDisposable dispose];

			BOOL noSubscribers = NO;
			@synchronized(self.subject.subscribers) {
				noSubscribers = self.subject.subscribers.count < 1;
			}
			
			if (noSubscribers) {
				@synchronized(self) {
					[self.disposable dispose];
					self.disposable = nil;
				}
			}
		}];
	}];
}

@end
