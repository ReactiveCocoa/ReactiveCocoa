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
	RACEagerSequence *sequence = [self sequenceWithArray:@[ value ] offset:0];
	sequence.name = [NSString stringWithFormat:@"+return: %@", value];
	return sequence;
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
	
	RACEagerSequence *sequence = [self.class sequenceWithArray:resultArray offset:0];
	sequence.name = self.name;
	return sequence;
}

- (instancetype)concat:(RACStream *)stream {
	NSParameterAssert(stream != nil);
	NSArray *array = [self.array arrayByAddingObjectsFromArray:((RACSequence *)stream).array];
	RACEagerSequence *sequence = [self.class sequenceWithArray:array offset:0];
	sequence.name = [NSString stringWithFormat:@"[%@] -concat: %@", self.name, stream];
	return sequence;
}

#pragma mark Extended methods

- (RACSequence *)eagerSequence {
	return self;
}

- (RACSequence *)lazySequence {
	return [RACArraySequence sequenceWithArray:self.array offset:0];
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len {
	return [self.array countByEnumeratingWithState:state objects:buffer count:len];
}

@end
