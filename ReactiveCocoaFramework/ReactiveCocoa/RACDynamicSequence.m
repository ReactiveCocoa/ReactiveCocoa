//
//  RACDynamicSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACDynamicSequence.h"

@interface RACDynamicSequence ()

@property (nonatomic, copy, readonly) id (^headBlock)(void);
@property (nonatomic, copy, readonly) RACSequence *(^tailBlock)(void);

@end

@implementation RACDynamicSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	NSParameterAssert(headBlock != nil);

	RACDynamicSequence *seq = [[self alloc] init];
	seq->_headBlock = [headBlock copy];
	seq->_tailBlock = [tailBlock copy];
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
	return self.headBlock();
}

- (RACSequence *)tail {
	if (self.tailBlock == nil) return nil;
	return self.tailBlock();
}

@end
