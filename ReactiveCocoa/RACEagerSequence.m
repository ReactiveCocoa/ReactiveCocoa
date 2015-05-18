//
//  RACEagerSequence.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 02/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACEagerSequence.h"
#import "NSObject+RACDescription.h"
#import "RACArraySequence.h"

@implementation RACEagerSequence

#pragma mark RACStream

+ (instancetype)return:(id)value {
	return [[self sequenceWithArray:@[ value ] offset:0] setNameWithFormat:@"+return: %@", RACDescription(value)];
}

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	NSCParameterAssert(block != nil);
	RACStreamBindBlock bindBlock = block();
	NSArray *currentArray = self.array;
	NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:currentArray.count];
	
	for (id value in currentArray) {
		BOOL stop = NO;
		RACSequence *boundValue = (id)bindBlock(value, &stop);
		if (boundValue == nil) break;

		for (id x in boundValue) {
			[resultArray addObject:x];
		}

		if (stop) break;
	}
	
	return [[self.class sequenceWithArray:resultArray offset:0] setNameWithFormat:@"[%@] -bind:", self.name];
}

- (instancetype)concat:(RACSequence *)sequence {
	NSCParameterAssert(sequence != nil);
	NSCParameterAssert([sequence isKindOfClass:RACSequence.class]);

	NSArray *array = [self.array arrayByAddingObjectsFromArray:sequence.array];
	return [[self.class sequenceWithArray:array offset:0] setNameWithFormat:@"[%@] -concat: %@", self.name, sequence];
}

#pragma mark Extended methods

- (RACSequence *)eagerSequence {
	return self;
}

- (RACSequence *)lazySequence {
	return [RACArraySequence sequenceWithArray:self.array offset:0];
}

- (id)foldRightWithStart:(id)start reduce:(id (^)(id, RACSequence *rest))reduce {
	return [super foldRightWithStart:start reduce:^(id first, RACSequence *rest) {
		return reduce(first, rest.eagerSequence);
	}];
}

@end
