//
//  RACSerialDisposable.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSerialDisposable.h"
#import <libkern/OSAtomic.h>

@interface RACSerialDisposable () {
	// A reference to the receiver's `disposable`. This variable must only be
	// modified atomically.
	//
	// If this is `self`, no `disposable` has been set, but the receiver has not
	// been disposed of yet. `self` is never stored retained.
	//
	// If this is `nil`, the receiver has been disposed.
	//
	// Otherwise, this is a retained reference to the inner disposable and the
	// receiver has not been disposed of yet.
	void * volatile _disposablePtr;
}

@end

@implementation RACSerialDisposable

#pragma mark Properties

- (BOOL)isDisposed {
	return _disposablePtr == nil;
}

- (RACDisposable *)disposable {
	RACDisposable *disposable = (__bridge id)_disposablePtr;
	return (disposable == self ? nil : disposable);
}

- (void)setDisposable:(RACDisposable *)disposable {
	[self swapInDisposable:disposable];
}

#pragma mark Lifecycle

+ (instancetype)serialDisposableWithDisposable:(RACDisposable *)disposable {
	RACSerialDisposable *serialDisposable = [[self alloc] init];
	serialDisposable.disposable = disposable;
	return serialDisposable;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_disposablePtr = (__bridge void *)self;
	OSMemoryBarrier();

	return self;
}

- (id)initWithBlock:(void (^)(void))block {
	self = [self init];
	if (self == nil) return nil;

	self.disposable = [RACDisposable disposableWithBlock:block];

	return self;
}

#pragma mark Inner Disposable

- (RACDisposable *)swapInDisposable:(RACDisposable *)newDisposable {
	void *existingDisposablePtr;

	// Keep trying while we're not disposed.
	while ((existingDisposablePtr = _disposablePtr) != NULL) {
		void *newDisposablePtr = (__bridge void *)(newDisposable ?: self);

		if (OSAtomicCompareAndSwapPtrBarrier(existingDisposablePtr, newDisposablePtr, &_disposablePtr)) {
			// Only retain the new disposable if it's not `self`.
			if (newDisposable != nil) CFRetain(newDisposablePtr);

			// Return nil if _disposablePtr was set to self. Otherwise, release
			// the old value and return it as an object.
			return (existingDisposablePtr == (__bridge void *)self ? nil : CFBridgingRelease(existingDisposablePtr));
		}
	}

	// At this point, we've found out that we were already disposed.
	[newDisposable dispose];
	return nil;
}

#pragma mark Disposal

- (void)dispose {
	void *existingDisposablePtr;

	while ((existingDisposablePtr = _disposablePtr) != NULL) {
		if (OSAtomicCompareAndSwapPtrBarrier(existingDisposablePtr, NULL, &_disposablePtr)) {
			if (existingDisposablePtr != (__bridge void *)self) {
				RACDisposable *existingDisposable = CFBridgingRelease(existingDisposablePtr);
				[existingDisposable dispose];
			}

			break;
		}
	}
}

@end
