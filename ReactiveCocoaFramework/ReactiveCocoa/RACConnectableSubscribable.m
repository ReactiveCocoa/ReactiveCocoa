//
//  RACConnectableSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSubscribable.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACSubscribable+Private.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "RACSubscribable+Operations.h"
#import "RACDisposable.h"

@interface RACConnectableSubscribable ()
@property (nonatomic, strong) id<RACSubscribable> sourceSubscribable;
@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACDisposable *disposable;
@end


@implementation RACConnectableSubscribable


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.subject subscribe:subscriber];
}


#pragma mark API

@synthesize sourceSubscribable;
@synthesize subject;
@synthesize disposable;

+ (instancetype)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source subject:(RACSubject *)subject {
	RACConnectableSubscribable *subscribable = [[self alloc] init];
	subscribable.sourceSubscribable = source;
	subscribable.subject = subject;
	return subscribable;
}

- (RACDisposable *)connect {
	@synchronized(self) {
		if(self.disposable == nil) {
			self.disposable = [self.sourceSubscribable subscribe:self.subject];
		}
		
		return self.disposable;
	}
}

- (RACSubscribable *)autoconnect {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		RACDisposable *subscriptionDisposable = [self subscribeNext:^(id x) {
			[subscriber sendNext:x];
		} error:^(NSError *error) {
			[subscriber sendError:error];
		} completed:^{
			[subscriber sendCompleted];
		}];
		
		RACDisposable *connectionDisposable = [self connect];
		
		return [RACDisposable disposableWithBlock:^{
			[subscriptionDisposable dispose];
			[connectionDisposable dispose];
			
			BOOL noSubscribers = NO;
			@synchronized(self.subscribers) {
				noSubscribers = self.subscribers.count < 1;
			}
			
			if(noSubscribers) {
				@synchronized(self) {
					self.disposable = nil;
				}
			}
		}];
	}];
}

@end
