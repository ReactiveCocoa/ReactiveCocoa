//
//  RACDisposable.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDisposable.h"
#import "RACScopedDisposable.h"
#import <libkern/OSAtomic.h>

@interface RACDisposable () {
	// A copied block of type void (^)(void) containing the logic for disposal,
	// a pointer to `self` if no logic should be performed upon disposal, or
	// NULL if the receiver is already disposed.
	//
	// This should only be used atomically.
	void * volatile _disposeBlock;
}

@end

@implementation RACDisposable

#pragma mark Properties

- (BOOL)isDisposed {
	return _disposeBlock == NULL;
}

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_disposeBlock = (__bridge void *)self;
	OSMemoryBarrier();

	return self;
}

- (id)initWithBlock:(void (^)(void))block {
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_disposeBlock = (void *)CFBridgingRetain([block copy]); 
	OSMemoryBarrier();

	return self;
}

+ (instancetype)disposableWithBlock:(void (^)(void))block {
	return [[self alloc] initWithBlock:block];
}

- (void)dealloc {
	if (_disposeBlock == NULL || _disposeBlock == (__bridge void *)self) return;

	CFRelease(_disposeBlock);
	_disposeBlock = NULL;
}

#pragma mark Disposal

- (void)dispose {
	void (^disposeBlock)(void) = NULL;

	while (YES) {
		void *blockPtr = _disposeBlock;
		if (OSAtomicCompareAndSwapPtrBarrier(blockPtr, NULL, &_disposeBlock)) {
			if (blockPtr != (__bridge void *)self) {
				disposeBlock = CFBridgingRelease(blockPtr);
			}

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
