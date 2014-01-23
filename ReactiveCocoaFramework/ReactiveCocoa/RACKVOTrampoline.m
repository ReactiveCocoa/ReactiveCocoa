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

static void *RACKVOWrapperContext = &RACKVOWrapperContext;

@interface RACKVOTrampoline ()

// The keypath which the trampoline is observing.
@property (nonatomic, readonly, copy) NSString *keyPath;

// These properties should only be manipulated while synchronized on the
// receiver.
@property (nonatomic, readonly, copy) RACKVOBlock block;
@property (nonatomic, readonly, unsafe_unretained) NSObject *target;

@end

@implementation RACKVOTrampoline

#pragma mark Lifecycle

- (instancetype)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	NSCParameterAssert(target != nil);
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_keyPath = [keyPath copy];

	_block = [block copy];
	_target = target;

	[self.target addObserver:self forKeyPath:self.keyPath options:options context:&RACKVOWrapperContext];
	[self.target.rac_deallocDisposable addDisposable:self];

	return self;
}

- (void)dealloc {
	[self dispose];
}

#pragma mark Observation

- (void)dispose {
	NSObject *target;

	@synchronized (self) {
		_block = nil;

		target = self.target;
		_target = nil;
	}

	[target.rac_deallocDisposable removeDisposable:self];
	[target removeObserver:self forKeyPath:self.keyPath context:&RACKVOWrapperContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context != &RACKVOWrapperContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	RACKVOBlock block;
	id target;

	@synchronized (self) {
		block = self.block;
		target = self.target;
	}

	if (block == nil) return;

	block(target, change);
}

@end
