//
//  RACSubscriber.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"
#import "RACDisposable.h"

@interface RACSubscriber ()
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, strong) RACDisposable *disposable;
@end


@implementation RACSubscriber

- (void)dealloc {
	[self stopSubscription];
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if(self.next != NULL) {
		self.next(value);
	}
}

- (void)sendError:(NSError *)e {
	[self stopSubscription];
	
	if(self.error != NULL) {
		self.error(e);
	}
}

- (void)sendCompleted {
	[self stopSubscription];
	
	if(self.completed != NULL) {
		self.completed();
	}
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	self.disposable = d;
}


#pragma mark API

@synthesize next;
@synthesize error;
@synthesize completed;
@synthesize disposable;

+ (id)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *subscriber = [[self alloc] init];
	subscriber.next = next;
	subscriber.error = error;
	subscriber.completed = completed;
	return subscriber;
}

- (void)stopSubscription {
	[self.disposable dispose];
	self.disposable = nil;
}

@end
