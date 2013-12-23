//
//  RACIndexSetSequence.m
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACIndexSetSequence.h"

@interface RACIndexSetSequence ()

@property (nonatomic) NSUInteger offset;
@property (nonatomic) NSData *indexes;
@end

@implementation RACIndexSetSequence

+ (instancetype)sequenceWithIndexSet:(NSIndexSet *)indexSet {
	RACIndexSetSequence *seq = [[self alloc] init];
	NSUInteger sizeInBytes = sizeof(NSUInteger) * indexSet.count;
	void *buff = malloc(sizeInBytes);
	[indexSet getIndexes:buff maxCount:indexSet.count inIndexRange:NULL];
	seq.indexes = [[NSData alloc] initWithBytesNoCopy:buff length:sizeInBytes freeWhenDone:YES];
	seq.offset = 0;
	
	return seq;
}

+ (instancetype)sequenceWithIndexSetSequence:(RACIndexSetSequence *)indexSetSequence offset:(NSUInteger)offset {
	RACIndexSetSequence *seq = [[self alloc] init];
	
	seq.indexes = indexSetSequence.indexes;
	seq.offset = offset;
	return seq;
}

#pragma mark - RACSequence

- (id)head {
	return @(((NSUInteger *)[self.indexes bytes])[self.offset]);
}

- (RACSequence *)tail {
	if (self.offset + 1 < self.indexes.length / sizeof(NSUInteger)) {
		return [self.class sequenceWithIndexSetSequence:self offset:self.offset + 1];
	}
	else {
		return RACSequence.empty;
	}
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id[])stackbuf count:(NSUInteger)len {
	NSCParameterAssert(len > 0);
	
	if (state->state >= self.indexes.length / sizeof(NSUInteger)) {
		// Enumeration has completed.
		return 0;
	}
	
	if (state->state == 0) {
		//enumeration begun, mark mutation flag
		state->mutationsPtr = state->extra;
	}
	
	state->itemsPtr = stackbuf;
	
	unsigned long index = 0;
	NSUInteger sizeInIndexes = self.indexes.length / sizeof(NSUInteger);
	while (index < MIN(sizeInIndexes - state->state, len)) {
		stackbuf[index] = @( ((NSUInteger *)self.indexes.bytes)[index + state->state] );
		++index;
	}
	
	state->state += index;
	return index;
}

#pragma mark NSObject

- (NSString *)description {
	NSMutableString *indexesStr = [NSMutableString string];
	NSUInteger sizeInIndexes = self.indexes.length / sizeof(NSUInteger);
	for (unsigned int i = 0; i < sizeInIndexes; ++i) {
		[indexesStr appendFormat:@"%@%lu", i ? @"," : @"", (unsigned long) ((NSUInteger *)self.indexes.bytes)[i] ];
	}
	return [NSString stringWithFormat:@"<%@: %p>{ name = %@, array = %@ }", self.class, self, self.name, indexesStr];
}

@end
