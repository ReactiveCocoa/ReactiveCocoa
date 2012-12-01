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

- (id)initWithDisposables:(NSArray *)disposables {
	self = [self init];
	if (self == nil) return nil;

	_disposables = [NSMutableArray array];
	if (disposables != nil) [_disposables addObjectsFromArray:disposables];

	return self;
}

#pragma mark Compound

- (void)addDisposable:(RACDisposable *)disposable {
	NSParameterAssert(disposable != nil);

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
		[self.disposables makeObjectsPerformSelector:@selector(dispose)];
		[self.disposables removeAllObjects];
	}
}

@end
