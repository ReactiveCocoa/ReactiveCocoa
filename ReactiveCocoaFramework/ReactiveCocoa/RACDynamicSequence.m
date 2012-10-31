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

+ (RACSequence *)sequenceWithGeneratorBlock:(id (^)(id))generatorBlock startingValue:(id)value {
	NSParameterAssert(generatorBlock != nil);

	return [self sequenceWithHeadBlock:^{
		return value;
	} tailBlock:^ RACSequence * {
		if (value == nil) return nil;
		return [self sequenceWithGeneratorBlock:generatorBlock startingValue:generatorBlock(value)];
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
