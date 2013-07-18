//
//  RACCompoundDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCompoundDisposable.h"
#import <libkern/OSAtomic.h>

@interface RACCompoundDisposable () {
	// Used for synchronization.
	OSSpinLock _spinLock;

	// Contains the receiver's disposables.
	//
	// This array should only be manipulated while _spinLock is held. If
	// `_disposed` is YES, this may be NULL.
	CFMutableArrayRef _disposables;

	// Whether the receiver has already been disposed.
	//
	// This ivar should only be accessed while _spinLock is held.
	BOOL _disposed;
}

@end

@implementation RACCompoundDisposable

#pragma mark Properties

- (BOOL)isDisposed {
	OSSpinLockLock(&_spinLock);
	BOOL disposed = _disposed;
	OSSpinLockUnlock(&_spinLock);

	return disposed;
}

#pragma mark Initializers

+ (instancetype)compoundDisposable {
	return [[self alloc] initWithDisposables:nil];
}

+ (instancetype)compoundDisposableWithDisposables:(NSArray *)disposables {
	return [[self alloc] initWithDisposables:disposables];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	// Use a CFArray for speed, and compare values using only pointer equality.
	CFArrayCallBacks callbacks = kCFTypeArrayCallBacks;
	callbacks.equal = NULL;

	_disposables = CFArrayCreateMutable(NULL, 0, &callbacks);

	return self;
}

- (id)initWithDisposables:(NSArray *)otherDisposables {
	self = [self init];
	if (self == nil) return nil;

	if (otherDisposables != nil) {
		CFArrayAppendArray(_disposables, (__bridge CFArrayRef)otherDisposables, CFRangeMake(0, (CFIndex)otherDisposables.count));
	}

	return self;
}

- (id)initWithBlock:(void (^)(void))block {
	RACDisposable *disposable = [RACDisposable disposableWithBlock:block];
	return [self initWithDisposables:@[ disposable ]];
}

- (void)dealloc {
	if (_disposables != NULL) {
		CFRelease(_disposables);
		_disposables = NULL;
	}
}

#pragma mark Compound

- (void)addDisposable:(RACDisposable *)disposable {
	NSCParameterAssert(disposable != nil);
	NSCParameterAssert(disposable != self);

	BOOL shouldDispose = NO;

	OSSpinLockLock(&_spinLock);
	{
		if (_disposed) {
			shouldDispose = YES;
		} else {
			CFArrayAppendValue(_disposables, (__bridge void *)disposable);
		}
	}
	OSSpinLockUnlock(&_spinLock);

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	if (shouldDispose) [disposable dispose];
}

- (void)removeDisposable:(RACDisposable *)disposable {
	if (disposable == nil) return;

	OSSpinLockLock(&_spinLock);
	{
		if (!_disposed) {
			CFIndex count = CFArrayGetCount(_disposables);
			for (CFIndex i = count - 1; i >= 0; i--) {
				const void *item = CFArrayGetValueAtIndex(_disposables, i);
				if (item == (__bridge void *)disposable) {
					CFArrayRemoveValueAtIndex(_disposables, i);
				}
			}
		}
	}
	OSSpinLockUnlock(&_spinLock);
}

#pragma mark RACDisposable

static void disposeEach(const void *value, void *context) {
	RACDisposable *disposable = (__bridge id)value;
	[disposable dispose];
}

- (void)dispose {
	CFArrayRef allDisposables = NULL;

	OSSpinLockLock(&_spinLock);
	{
		_disposed = YES;

		allDisposables = _disposables;
		_disposables = NULL;
	}
	OSSpinLockUnlock(&_spinLock);

	if (allDisposables == NULL) return;

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	CFIndex count = CFArrayGetCount(allDisposables);
	CFArrayApplyFunction(allDisposables, CFRangeMake(0, count), &disposeEach, NULL);
	CFRelease(allDisposables);
}

@end
