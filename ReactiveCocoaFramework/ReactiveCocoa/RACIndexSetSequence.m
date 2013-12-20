//
//  RACIndexSetSequence.m
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACIndexSetSequence.h"

@interface RACIndexSetSequence ()
{
	NSUInteger *_indexes;
	NSUInteger _size;
}
@end

@implementation RACIndexSetSequence

+ (instancetype)seqneceWithIndexSet:(NSIndexSet *)indexSet {
	RACIndexSetSequence *seq = [[self alloc] init];
	seq->_indexes = malloc(sizeof(NSUInteger) * indexSet.count);
    [indexSet getIndexes:seq->_indexes maxCount:indexSet.count inIndexRange:NULL];
	seq->_size = indexSet.count;
	
	return seq;
}

+ (instancetype)seqneceWithRawIndexSet:(const NSUInteger *)indexSetBuff size:(NSUInteger)size{
	RACIndexSetSequence *seq = [[self alloc] init];
	
	seq->_indexes = malloc(sizeof(NSUInteger) * size);
	memcpy(seq->_indexes, indexSetBuff, sizeof(NSUInteger) * size);
	seq->_size = size;
	return seq;
}

- (void)dealloc {
	if (_indexes) {
		free(_indexes);
		_indexes = NULL;
	}
}


#pragma mark - RACSequence

- (id) head {
	return @(*_indexes);
}

- (RACSequence *)tail {
    if (_size - 1) {
        return [self.class seqneceWithRawIndexSet:&_indexes[1] size:_size - 1];
    }
    else {
        return RACSequence.empty;
    }
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id[])stackbuf count:(NSUInteger)len {
	NSCParameterAssert(len > 0);
	
	if (state->state >= _size) {
		// Enumeration has completed.
		return 0;
	}
	
	state->mutationsPtr = state->extra;
	
	state->itemsPtr = stackbuf;
	
	unsigned long index = 0;
	while (index < MIN(_size - state->state, len)) {
		stackbuf[index] = @(_indexes[index + state->state]);
		++index;
	}
	
	state->state += index;
	return index;
}

@end
