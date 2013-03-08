//
//  RACEagerSequence.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 02/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACEagerSequence.h"
#import "RACArraySequence.h"

@implementation RACEagerSequence

#pragma mark RACStream

+ (instancetype)return:(id)value {
	return [[self sequenceWithArray:@[ value ] offset:0] setNameWithFormat:@"+return: %@", value];
}

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	NSParameterAssert(block != nil);
	RACStreamBindBlock bindBlock = block();
	NSArray *currentArray = self.array;
	NSMutableArray *resultArray = [NSMutableArray arrayWithCapacity:currentArray.count];
	
	for (id value in currentArray) {
		BOOL stop = NO;
		RACSequence *boundValue = (id)bindBlock(value, &stop);
		if (boundValue == nil) break;
		[resultArray addObjectsFromArray:boundValue.array];
		if (stop) break;
	}
	
	return [[self.class sequenceWithArray:resultArray offset:0] setNameWithFormat:@"[%@] -bind:", self.name];
}

- (instancetype)concat:(RACSequence *)sequence {
	NSParameterAssert(sequence != nil);
	NSParameterAssert([sequence isKindOfClass:RACSequence.class]);

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

- (id)foldRightWithStart:(id)start combine:(id (^)(id, RACSequence *rest))combine {
	return [super foldRightWithStart:start combine:^(id first, RACSequence *rest) {
		return combine(first, rest.eagerSequence);
	}];
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len {
	return [self.array countByEnumeratingWithState:state objects:buffer count:len];
}

@end
