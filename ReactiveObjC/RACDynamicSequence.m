//
//  RACDynamicSequence.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACDynamicSequence.h"
#import <libkern/OSAtomic.h>

// Determines how RACDynamicSequences will be deallocated before the next one is
// shifted onto the autorelease pool.
//
// This avoids stack overflows when deallocating long chains of dynamic
// sequences.
#define DEALLOC_OVERFLOW_GUARD 100

@interface RACDynamicSequence () {
	// The value for the "head" property, if it's been evaluated already.
	//
	// Because it's legal for head to be nil, this ivar is valid any time
	// headBlock is nil.
	//
	// This ivar should only be accessed while synchronized on self.
	id _head;

	// The value for the "tail" property, if it's been evaluated already.
	//
	// Because it's legal for tail to be nil, this ivar is valid any time
	// tailBlock is nil.
	//
	// This ivar should only be accessed while synchronized on self.
	RACSequence *_tail;

	// The result of an evaluated `dependencyBlock`.
	//
	// This ivar is valid any time `hasDependency` is YES and `dependencyBlock`
	// is nil.
	//
	// This ivar should only be accessed while synchronized on self.
	id _dependency;
}

// A block used to evaluate head. This should be set to nil after `_head` has been
// initialized.
//
// This is marked `strong` instead of `copy` because of some bizarre block
// copying bug. See https://github.com/ReactiveCocoa/ReactiveCocoa/pull/506.
//
// The signature of this block varies based on the value of `hasDependency`:
//
//  - If YES, this block is of type `id (^)(id)`.
//  - If NO, this block is of type `id (^)(void)`.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, strong) id headBlock;

// A block used to evaluate tail. This should be set to nil after `_tail` has been
// initialized.
//
// This is marked `strong` instead of `copy` because of some bizarre block
// copying bug. See https://github.com/ReactiveCocoa/ReactiveCocoa/pull/506.
//
// The signature of this block varies based on the value of `hasDependency`:
//
//  - If YES, this block is of type `RACSequence * (^)(id)`.
//  - If NO, this block is of type `RACSequence * (^)(void)`.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, strong) id tailBlock;

// Whether the receiver was initialized with a `dependencyBlock`.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, assign) BOOL hasDependency;

// A dependency which must be evaluated before `headBlock` and `tailBlock`. This
// should be set to nil after `_dependency` and `dependencyBlockExecuted` have
// been set.
//
// This is marked `strong` instead of `copy` because of some bizarre block
// copying bug. See https://github.com/ReactiveCocoa/ReactiveCocoa/pull/506.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, strong) id (^dependencyBlock)(void);

@end

@implementation RACDynamicSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	NSCParameterAssert(headBlock != nil);

	RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
	seq.headBlock = [headBlock copy];
	seq.tailBlock = [tailBlock copy];
	seq.hasDependency = NO;
	return seq;
}

+ (RACSequence *)sequenceWithLazyDependency:(id (^)(void))dependencyBlock headBlock:(id (^)(id dependency))headBlock tailBlock:(RACSequence *(^)(id dependency))tailBlock {
	NSCParameterAssert(dependencyBlock != nil);
	NSCParameterAssert(headBlock != nil);

	RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
	seq.headBlock = [headBlock copy];
	seq.tailBlock = [tailBlock copy];
	seq.dependencyBlock = [dependencyBlock copy];
	seq.hasDependency = YES;
	return seq;
}

- (void)dealloc {
	static volatile int32_t directDeallocCount = 0;

	if (OSAtomicIncrement32(&directDeallocCount) >= DEALLOC_OVERFLOW_GUARD) {
		OSAtomicAdd32(-DEALLOC_OVERFLOW_GUARD, &directDeallocCount);

		// Put this sequence's tail onto the autorelease pool so we stop
		// recursing.
		__autoreleasing RACSequence *tail __attribute__((unused)) = _tail;
	}
	
	_tail = nil;
}

#pragma mark RACSequence

- (id)head {
	@synchronized (self) {
		id untypedHeadBlock = self.headBlock;
		if (untypedHeadBlock == nil) return _head;

		if (self.hasDependency) {
			if (self.dependencyBlock != nil) {
				_dependency = self.dependencyBlock();
				self.dependencyBlock = nil;
			}

			id (^headBlock)(id) = untypedHeadBlock;
			_head = headBlock(_dependency);
		} else {
			id (^headBlock)(void) = untypedHeadBlock;
			_head = headBlock();
		}

		self.headBlock = nil;
		return _head;
	}
}

- (RACSequence *)tail {
	@synchronized (self) {
		id untypedTailBlock = self.tailBlock;
		if (untypedTailBlock == nil) return _tail;

		if (self.hasDependency) {
			if (self.dependencyBlock != nil) {
				_dependency = self.dependencyBlock();
				self.dependencyBlock = nil;
			}

			RACSequence * (^tailBlock)(id) = untypedTailBlock;
			_tail = tailBlock(_dependency);
		} else {
			RACSequence * (^tailBlock)(void) = untypedTailBlock;
			_tail = tailBlock();
		}

		if (_tail.name == nil) _tail.name = self.name;

		self.tailBlock = nil;
		return _tail;
	}
}

#pragma mark NSObject

- (NSString *)description {
	id head = @"(unresolved)";
	id tail = @"(unresolved)";

	@synchronized (self) {
		if (self.headBlock == nil) head = _head;
		if (self.tailBlock == nil) {
			tail = _tail;
			if (tail == self) tail = @"(self)";
		}
	}

	return [NSString stringWithFormat:@"<%@: %p>{ name = %@, head = %@, tail = %@ }", self.class, self, self.name, head, tail];
}

@end
