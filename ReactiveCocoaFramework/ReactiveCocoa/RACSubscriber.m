//
//  RACSubscriber.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"

@interface RACSubscriber ()

@property (nonatomic, copy, readonly) void (^next)(id value);
@property (nonatomic, copy, readonly) void (^error)(NSError *error);
@property (nonatomic, copy, readonly) void (^completed)(void);
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

// This property should only be used while synchronized on self.
@property (nonatomic, assign) BOOL disposed;

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

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	@weakify(self);

	RACDisposable *selfDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);

		@synchronized (self) {
			self.disposed = YES;
		}
	}];

	_disposable = [RACCompoundDisposable compoundDisposable];
	[_disposable addDisposable:selfDisposable];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if (self.next == NULL) return;

	@synchronized (self) {
		if (self.disposed) return;
		self.next(value);
	}
}

- (void)sendError:(NSError *)e {
	@synchronized (self) {
		if (self.disposed) return;

		[self.disposable dispose];
		if (self.error != NULL) self.error(e);
	}
}

- (void)sendCompleted {
	@synchronized (self) {
		if (self.disposed) return;

		[self.disposable dispose];
		if (self.completed != NULL) self.completed();
	}
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	if (d != nil) [self.disposable addDisposable:d];
}

@end
