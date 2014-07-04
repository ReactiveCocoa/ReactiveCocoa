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
@property (nonatomic, readonly, unsafe_unretained) NSObject *observer;

@end

@implementation RACKVOTrampoline

#pragma mark Lifecycle

- (id)initWithTarget:(NSObject *)target observer:(NSObject *)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	NSCParameterAssert(target != nil);
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_keyPath = [keyPath copy];

	_block = [block copy];
	_target = target;
	_observer = observer;

	[self.target addObserver:self forKeyPath:self.keyPath options:options context:&RACKVOWrapperContext];
	[self.target.rac_deallocDisposable addDisposable:self];
	[self.observer.rac_deallocDisposable addDisposable:self];

	return self;
}

- (void)dealloc {
	[self dispose];
}

#pragma mark Observation

- (void)dispose {
	NSObject *target;
	NSObject *observer;

	@synchronized (self) {
		_block = nil;

		target = self.target;
		observer = self.observer;

		_target = nil;
		_observer = nil;
	}

	[target.rac_deallocDisposable removeDisposable:self];
	[observer.rac_deallocDisposable removeDisposable:self];

	[target removeObserver:self forKeyPath:self.keyPath context:&RACKVOWrapperContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context != &RACKVOWrapperContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	RACKVOBlock block;
	id observer;
	id target;

	@synchronized (self) {
		block = self.block;
		observer = self.observer;
		target = self.target;
	}

	if (block == nil) return;

	block(target, observer, change);
}

@end
