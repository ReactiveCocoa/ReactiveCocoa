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

	OSSpinLock _spinLock;
}

@end

@implementation RACSerialDisposable

#pragma mark Properties

- (BOOL)isDisposed {
	return _disposablePtr == nil;
}

- (RACDisposable *)disposable {
	RACDisposable *result;

	OSSpinLockLock(&_spinLock);
	RACDisposable *disposable = (__bridge id)_disposablePtr;
	result = (disposable == self ? nil : disposable);
	OSSpinLockUnlock(&_spinLock);

	return result;
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

- (void)dealloc {
	self.disposable = nil;
}

#pragma mark Inner Disposable

- (RACDisposable *)swapInDisposable:(RACDisposable *)newDisposable {

	RACDisposable *existingDisposable;
	BOOL alreadyDisposed;
	OSSpinLockLock(&_spinLock);
	// Have we already been disposed?
	if (_disposablePtr == nil) {
		alreadyDisposed = YES;
	}
	else {
		alreadyDisposed = NO;

		if (_disposablePtr != (__bridge void *)self) {
			existingDisposable = (__bridge_transfer RACDisposable *)_disposablePtr;
		}
		if (newDisposable) {
			_disposablePtr = (void *)CFBridgingRetain(newDisposable);
		}
		else {
			_disposablePtr = (__bridge void *)self;
		}
	}
	OSSpinLockUnlock(&_spinLock);

	if (alreadyDisposed) {
		[newDisposable dispose];
		return nil;
	}

	return existingDisposable;
}

#pragma mark Disposal

- (void)dispose {
	RACDisposable *existingDisposable;

	OSSpinLockLock(&_spinLock);
	if (_disposablePtr != (__bridge void *)self) {
		existingDisposable = (__bridge_transfer RACDisposable *)_disposablePtr;
	}
	_disposablePtr = nil;
	OSSpinLockUnlock(&_spinLock);
	
	[existingDisposable dispose];
}

@end
