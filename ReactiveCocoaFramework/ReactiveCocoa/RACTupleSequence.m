//
//  RACTupleSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTupleSequence.h"
#import "RACTuple.h"

@interface RACTupleSequence ()

// The array being sequenced, as taken from RACTuple.backingArray.
@property (nonatomic, strong, readonly) NSArray *tupleBackingArray;

// The index in the array from which the sequence starts.
@property (nonatomic, assign, readonly) NSUInteger offset;

@end

@implementation RACTupleSequence

#pragma mark Lifecycle

+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset {
	NSCParameterAssert(offset <= backingArray.count);

	if (offset == backingArray.count) return self.empty;

	RACTupleSequence *seq = [[self alloc] init];
	seq->_tupleBackingArray = backingArray;
	seq->_offset = offset;
	return seq;
}

#pragma mark RACSequence

- (id)head {
	id object = [self.tupleBackingArray objectAtIndex:self.offset];
	return (object == RACTupleNil.tupleNil ? NSNull.null : object);
}

- (RACSequence *)tail {
	RACSequence *sequence = [self.class sequenceWithTupleBackingArray:self.tupleBackingArray offset:self.offset + 1];
	sequence.name = self.name;
	return sequence;
}

- (NSArray *)array {
	NSRange range = NSMakeRange(self.offset, self.tupleBackingArray.count - self.offset);
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:range.length];

	[self.tupleBackingArray enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] options:0 usingBlock:^(id object, NSUInteger index, BOOL *stop) {
		id mappedObject = (object == RACTupleNil.tupleNil ? NSNull.null : object);
		[array addObject:mappedObject];
	}];

	return array;
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ name = %@, tuple = %@ }", self.class, self, self.name, self.tupleBackingArray];
}

@end
