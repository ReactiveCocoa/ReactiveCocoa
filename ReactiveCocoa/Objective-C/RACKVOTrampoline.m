//
//  RACKVOTrampoline.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 1/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACKVOTrampoline.h"
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACKVOProxy.h"

@interface RACKVOTrampoline ()

// The keypath which the trampoline is observing.
@property (nonatomic, readonly, copy) NSString *keyPath;

// These properties should only be manipulated while synchronized on the
// receiver.
@property (nonatomic, readonly, copy) RACKVOBlock block;
@property (nonatomic, readonly, unsafe_unretained) NSObject *unsafeTarget;
@property (nonatomic, readonly, weak) NSObject *weakTarget;
@property (nonatomic, readonly, weak) NSObject *observer;

@end

@implementation RACKVOTrampoline

#pragma mark Lifecycle

- (id)initWithTarget:(__weak NSObject *)target observer:(__weak NSObject *)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(block != nil);

	NSObject *strongTarget = target;
	if (strongTarget == nil) return nil;

	self = [super init];
	if (self == nil) return nil;

	_keyPath = [keyPath copy];

	_block = [block copy];
	_weakTarget = target;
	_unsafeTarget = strongTarget;
	_observer = observer;

	[RACKVOProxy.sharedProxy addObserver:self forContext:(__bridge void *)self];
	[strongTarget addObserver:RACKVOProxy.sharedProxy forKeyPath:self.keyPath options:options context:(__bridge void *)self];

	[strongTarget.rac_deallocDisposable addDisposable:self];
	[self.observer.rac_deallocDisposable addDisposable:self];

	return self;
}

- (void)dealloc {
	[self dispose];
}

#pragma mark Observation

- (void)dispose {
	NSObject *target;
	NSObject *observer;

	@synchronized (self) {
		_block = nil;

		// The target should still exist at this point, because we still need to
		// tear down its KVO observation. Therefore, we can use the unsafe
		// reference (and need to, because the weak one will have been zeroed by
		// now).
		target = self.unsafeTarget;
		observer = self.observer;

		_unsafeTarget = nil;
		_observer = nil;
	}

	[target.rac_deallocDisposable removeDisposable:self];
	[observer.rac_deallocDisposable removeDisposable:self];

	[target removeObserver:RACKVOProxy.sharedProxy forKeyPath:self.keyPath context:(__bridge void *)self];
	[RACKVOProxy.sharedProxy removeObserver:self forContext:(__bridge void *)self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context != (__bridge void *)self) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	RACKVOBlock block;
	id observer;
	id target;

	@synchronized (self) {
		block = self.block;
		observer = self.observer;
		target = self.weakTarget;
	}

	if (block == nil || target == nil) return;

	block(target, observer, change);
}

@end
