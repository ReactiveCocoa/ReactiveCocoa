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
}

// These properties should only be accessed while _spinLock is held.
@property (nonatomic, strong) NSMutableArray *disposables;
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

	_disposables = [NSMutableArray array];

	return self;
}

- (id)initWithDisposables:(NSArray *)disposables {
	self = [self init];
	if (self == nil) return nil;

	if (disposables != nil) [self.disposables addObjectsFromArray:disposables];

	return self;
}

#pragma mark Compound

- (void)addDisposable:(RACDisposable *)disposable {
	NSCParameterAssert(disposable != nil);
	NSCParameterAssert(disposable != self);

	BOOL shouldDispose = NO;

	{
		OSSpinLockLock(&_spinLock);

		// Ensures exception safety.
		@onExit {
			OSSpinLockUnlock(&_spinLock);
		};

		if (self.disposed) {
			shouldDispose = YES;
		} else {
			[self.disposables addObject:disposable];
		}
	}

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	if (shouldDispose) [disposable dispose];
}

- (void)removeDisposable:(RACDisposable *)disposable {
	if (disposable == nil) return;

	OSSpinLockLock(&_spinLock);

	// Ensures exception safety.
	@onExit {
		OSSpinLockUnlock(&_spinLock);
	};

	[self.disposables removeObjectIdenticalTo:disposable];
}

#pragma mark RACDisposable

- (void)dispose {
	NSArray *disposables = nil;

	{
		OSSpinLockLock(&_spinLock);

		// Ensures exception safety.
		@onExit {
			OSSpinLockUnlock(&_spinLock);
		};

		self.disposed = YES;

		disposables = self.disposables;
		self.disposables = nil;
	}

	// Performed outside of the lock in case the compound disposable is used
	// recursively.
	[disposables makeObjectsPerformSelector:@selector(dispose)];
}

@end
