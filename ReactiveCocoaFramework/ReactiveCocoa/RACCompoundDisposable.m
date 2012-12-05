//
//  RACCompoundDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCompoundDisposable.h"

@interface RACCompoundDisposable ()

// These properties should only be accessed while synchronized on self.
@property (nonatomic, readonly, strong) NSMutableArray *disposables;
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

	if (disposables != nil) [_disposables addObjectsFromArray:disposables];

	return self;
}

#pragma mark Compound

- (void)addDisposable:(RACDisposable *)disposable {
	NSParameterAssert(disposable != nil);
	NSParameterAssert(disposable != self);

	@synchronized(self) {
		if (self.disposed) {
			[disposable dispose];
		} else {
			[self.disposables addObject:disposable];
		}
	}
}

#pragma mark RACDisposable

- (void)dispose {
	@synchronized(self) {
		self.disposed = YES;

		// Copy the disposables so there's no way that we could recursively
		// modify (in -addDisposable:) the array we're disposing.
		NSArray *disposablesCopy = [self.disposables copy];
		[self.disposables removeAllObjects];
		[disposablesCopy makeObjectsPerformSelector:@selector(dispose)];
	}
}

@end
