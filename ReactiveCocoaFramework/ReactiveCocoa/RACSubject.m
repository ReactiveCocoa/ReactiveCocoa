//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"
#import "RACSubscribable+Private.h"
#import "RACDisposable.h"

@interface RACSubject ()
@property (nonatomic, strong) RACDisposable *disposable;
@end


@implementation RACSubject


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self stopSubscription];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];
}

- (void)sendCompleted {
	[self stopSubscription];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	}];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	self.disposable = d;
}


#pragma mark API

@synthesize disposable;

+ (id)subject {
	return [[self alloc] init];
}

- (void)stopSubscription {
	[self.disposable dispose];
	self.disposable = nil;
}

@end
