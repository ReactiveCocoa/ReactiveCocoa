//
//  RACCompoundDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCompoundDisposable.h"
#import "EXTScope.h"
#import <libkern/OSAtomic.h>

@interface RACCompoundDisposable () {
	// Used for synchronization.
	OSSpinLock _spinLock;

	// Contains the receiver's disposables.
	//
	// This array should only be manipulated while _spinLock is held. If
	// `disposed` is YES, this may be NULL.
	CFMutableArrayRef _disposables;
}

// Whether the receiver has already been disposed.
//
// This property should only be accessed while _spinLock is held.
@property (nonatomic, assign, getter = isDisposed) BOOL disposed;

@end

@implementation RACCompoundDisposable

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
	@try {
		if (self.disposed) {
			shouldDispose = YES;
		} else {
			CFArrayAppendValue(_disposables, (__bridge void *)disposable);
		}
	} @finally {
		OSSpinLockUnlock(&_spinLock);
	}

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	if (shouldDispose) [disposable dispose];
}

- (void)removeDisposable:(RACDisposable *)disposable {
	if (disposable == nil) return;

	OSSpinLockLock(&_spinLock);
	@try {
		if (self.disposed) return;

		CFIndex count = CFArrayGetCount(_disposables);

		const void *items[count];
		CFArrayGetValues(_disposables, CFRangeMake(0, count), items);

		for (CFIndex i = count - 1; i >= 0; i--) {
			if (items[i] == (__bridge void *)disposable) {
				CFArrayRemoveValueAtIndex(_disposables, i);
			}
		}
	} @finally {
		OSSpinLockUnlock(&_spinLock);
	}
}

#pragma mark RACDisposable

- (void)dispose {
	CFArrayRef allDisposables = NULL;

	OSSpinLockLock(&_spinLock);
	@try {
		self.disposed = YES;

		allDisposables = _disposables;
		_disposables = NULL;
	} @finally {
		OSSpinLockUnlock(&_spinLock);
	}

	if (allDisposables == NULL) return;

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	CFIndex count = CFArrayGetCount(allDisposables);

	const void *items[count];
	CFArrayGetValues(allDisposables, CFRangeMake(0, count), items);

	for (CFIndex i = 0; i < count; i++) {
		__unsafe_unretained RACDisposable *disposable = (__bridge id)items[i];
		[disposable dispose];
	}

	CFRelease(allDisposables);
}

@end
