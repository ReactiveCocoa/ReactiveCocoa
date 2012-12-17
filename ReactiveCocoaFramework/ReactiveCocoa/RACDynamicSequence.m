//
//  RACDynamicSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACDynamicSequence.h"

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
}

// A block used to evaluate head. This should be set to nil after _head has been
// initialized.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, copy) id (^headBlock)(void);

// A block used to evaluate tail. This should be set to nil after _tail has been
// initialized.
//
// This property should only be accessed while synchronized on self.
@property (nonatomic, copy) RACSequence *(^tailBlock)(void);

@end

@implementation RACDynamicSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	NSParameterAssert(headBlock != nil);

	RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
	seq.headBlock = [headBlock copy];
	seq.tailBlock = [tailBlock copy];
	return seq;
}

+ (RACSequence *)sequenceWithLazyDependency:(id (^)(void))dependencyBlock headBlock:(id (^)(id dependency))headBlock tailBlock:(RACSequence *(^)(id dependency))tailBlock {
	NSParameterAssert(dependencyBlock != nil);
	NSParameterAssert(headBlock != nil);

	NSLock *lock = [[NSLock alloc] init];

	__block id dependency = nil;
	__block BOOL dependencyBlockExecuted = NO;

	id (^evaluateDependency)(void) = [^{
		[lock lock];
		if (!dependencyBlockExecuted) {
			dependency = dependencyBlock();
			dependencyBlockExecuted = YES;
		}
		[lock unlock];

		return dependency;
	} copy];

	return [self sequenceWithHeadBlock:^{
		return headBlock(evaluateDependency());
	} tailBlock:^ id {
		if (tailBlock == nil) return nil;
		return tailBlock(evaluateDependency());
	}];
}

#pragma mark RACSequence

- (id)head {
	@synchronized (self) {
		if (self.headBlock != nil) {
			_head = self.headBlock();
			self.headBlock = nil;
		}

		return _head;
	}
}

- (RACSequence *)tail {
	@synchronized (self) {
		if (self.tailBlock != nil) {
			_tail = self.tailBlock();
			self.tailBlock = nil;
		}

		return _tail;
	}
}

#pragma mark NSObject

- (NSString *)description {
	id head = @"(unresolved)";
	id tail = @"(unresolved)";

	@synchronized (self) {
		if (self.headBlock == nil) head = _head;
		if (self.tailBlock == nil) tail = _tail;
	}

	return [NSString stringWithFormat:@"<%@: %p>{ head = %@, tail = %@ }", self.class, self, head, tail];
}

@end
