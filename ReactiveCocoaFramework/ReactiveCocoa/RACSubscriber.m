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

@property (nonatomic, copy, readonly) void (^next)(id value);
@property (nonatomic, copy, readonly) void (^error)(NSError *error);
@property (nonatomic, copy, readonly) void (^completed)(void);

// These properties should only be accessed while synchronized on self.
@property (nonatomic, strong) RACDisposable *disposable;
@property (nonatomic, assign) BOOL completedOrErrored;

// Disposes of and releases the receiver's disposable.
- (void)stopSubscription;

@end

@implementation RACSubscriber

#pragma mark Lifecycle

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACSubscriber *subscriber = [[self alloc] init];

	subscriber->_next = [next copy];
	subscriber->_error = [error copy];
	subscriber->_completed = [completed copy];

	return subscriber;
}

- (void)stopSubscription {
	@synchronized (self) {
		[self.disposable dispose];
		self.disposable = nil;
	}
}

- (void)dealloc {
	[self stopSubscription];
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if (self.next != NULL) {
		@synchronized (self) {
			if (self.completedOrErrored) return;

			self.next(value);
		}
	}
}

- (void)sendError:(NSError *)e {
	@synchronized (self) {
		if (self.completedOrErrored) return;

		self.completedOrErrored = YES;
		[self stopSubscription];
	
		if (self.error != NULL) self.error(e);
	}
}

- (void)sendCompleted {
	@synchronized (self) {
		if (self.completedOrErrored) return;

		self.completedOrErrored = YES;
		[self stopSubscription];
		
		if (self.completed != NULL) self.completed();
	}
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	@synchronized (self) {
		self.disposable = d;
		if (self.completedOrErrored) [self stopSubscription];
	}
}

@end
