//
//  RACSubject.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"
#import <ReactiveObjC/EXTScope.h>
#import "RACCompoundDisposable.h"
#import "RACPassthroughSubscriber.h"

@interface RACSubject ()

// Contains all current subscribers to the receiver.
//
// This should only be used while synchronized on `self`.
@property (nonatomic, strong, readonly) NSMutableArray *subscribers;

// Contains all of the receiver's subscriptions to other signals.
@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

// Enumerates over each of the receiver's `subscribers` and invokes `block` for
// each.
- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block;

@end

@implementation RACSubject

#pragma mark Lifecycle

+ (instancetype)subject {
	return [[self alloc] init];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_disposable = [RACCompoundDisposable compoundDisposable];
	_subscribers = [[NSMutableArray alloc] initWithCapacity:1];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark Subscription

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];

	NSMutableArray *subscribers = self.subscribers;
	@synchronized (subscribers) {
		[subscribers addObject:subscriber];
	}
	
	[disposable addDisposable:[RACDisposable disposableWithBlock:^{
		@synchronized (subscribers) {
			// Since newer subscribers are generally shorter-lived, search
			// starting from the end of the list.
			NSUInteger index = [subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
				return obj == subscriber;
			}];

			if (index != NSNotFound) [subscribers removeObjectAtIndex:index];
		}
	}]];

	return disposable;
}

- (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block {
	NSArray *subscribers;
	@synchronized (self.subscribers) {
		subscribers = [self.subscribers copy];
	}

	for (id<RACSubscriber> subscriber in subscribers) {
		block(subscriber);
	}
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self.disposable dispose];
	
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];
}

- (void)sendCompleted {
	[self.disposable dispose];
	
	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	}];
}

- (void)didSubscribeWithDisposable:(RACCompoundDisposable *)d {
	if (d.disposed) return;
	[self.disposable addDisposable:d];

	@weakify(self, d);
	[d addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(self, d);
		[self.disposable removeDisposable:d];
	}]];
}

@end
