//
//  RACDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDisposable.h"
#import "RACScopedDisposable.h"
#import <libkern/OSAtomic.h>

@interface RACDisposable () {
	// A copied block of type void (^)(void) containing the logic for disposal,
	// or NULL if the receiver is already disposed.
	//
	// This should only be used atomically.
	void * volatile _disposeBlock;
}

@end

@implementation RACDisposable

#pragma mark Lifecycle

+ (instancetype)disposableWithBlock:(void (^)(void))block {
	RACDisposable *disposable = [[self alloc] init];

	id copiedBlock = [block copy];
	disposable->_disposeBlock = (void *)CFBridgingRetain(copiedBlock);

	// Force the store to _disposeBlock to complete.
	OSMemoryBarrier();

	return disposable;
}

- (void)dealloc {
	if (_disposeBlock != NULL) {
		CFRelease(_disposeBlock);
		_disposeBlock = NULL;
	}
}

#pragma mark Disposal

- (void)dispose {
	void (^disposeBlock)(void) = NULL;

	while (YES) {
		void *blockPtr = _disposeBlock;
		if (OSAtomicCompareAndSwapPtrBarrier(blockPtr, NULL, &_disposeBlock)) {
			disposeBlock = CFBridgingRelease(blockPtr);
			break;
		}
	}

	if (disposeBlock != nil) disposeBlock();
}

#pragma mark Scoped Disposables

- (RACScopedDisposable *)asScopedDisposable {
	return [RACScopedDisposable scopedDisposableWithDisposable:self];
}

@end
