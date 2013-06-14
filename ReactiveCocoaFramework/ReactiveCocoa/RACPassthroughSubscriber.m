//
//  RACPassthroughSubscriber.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPassthroughSubscriber.h"
#import "RACDisposable.h"

@interface RACPassthroughSubscriber ()

// The subscriber to which events should be forwarded.
@property (nonatomic, strong, readonly) id<RACSubscriber> innerSubscriber;

// A disposable representing the subscription. When disposed, no further events
// should be sent to the `innerSubscriber`.
@property (nonatomic, strong, readonly) RACDisposable *disposable;

@end

@implementation RACPassthroughSubscriber

#pragma mark Lifecycle

- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber disposable:(RACDisposable *)disposable {
	NSCParameterAssert(subscriber != nil);

	self = [super init];
	if (self == nil) return nil;

	_innerSubscriber = subscriber;
	_disposable = disposable;

	return self;
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if (self.disposable.disposed) return;
	[self.innerSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	if (self.disposable.disposed) return;
	[self.innerSubscriber sendError:error];
}

- (void)sendCompleted {
	if (self.disposable.disposed) return;
	[self.innerSubscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	if (self.disposable.disposed) {
		[disposable dispose];
		return;
	}

	// We don't actually need to save this disposable, since the inner
	// subscriber will take care of it. We only care about cutting off the event
	// stream.
	[self.innerSubscriber didSubscribeWithDisposable:disposable];
}

@end
