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
@property (assign) BOOL completedOrErrored;
@end


@implementation RACSubject


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	self.completedOrErrored = YES;

	[self stopSubscription];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];
}

- (void)sendCompleted {
	self.completedOrErrored = YES;

	[self stopSubscription];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	}];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	@synchronized(self) {
		self.disposable = d;
	}

	if (self.completedOrErrored) {
		[self stopSubscription];
	}
}


#pragma mark API

@synthesize disposable;

+ (instancetype)subject {
	return [[self alloc] init];
}

- (void)stopSubscription {
	@synchronized(self) {
		[self.disposable dispose];
		self.disposable = nil;
	}
}

@end
