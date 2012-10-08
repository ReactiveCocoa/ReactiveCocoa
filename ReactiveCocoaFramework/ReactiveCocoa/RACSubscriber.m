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
@property (assign) BOOL completedOrErrored;
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
	self.completedOrErrored = YES;

	[self stopSubscription];
	
	if(self.error != NULL) {
		self.error(e);
	}
}

- (void)sendCompleted {
	self.completedOrErrored = YES;

	[self stopSubscription];
	
	if(self.completed != NULL) {
		self.completed();
	}
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

@synthesize next;
@synthesize error;
@synthesize completed;
@synthesize disposable;

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *subscriber = [[self alloc] init];
	subscriber.next = next;
	subscriber.error = error;
	subscriber.completed = completed;
	return subscriber;
}

- (void)stopSubscription {
	@synchronized(self) {
		[self.disposable dispose];
		self.disposable = nil;
	}
}

@end
