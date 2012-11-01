//
//  RACSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"
#import "RACArraySequence.h"
#import "RACDynamicSequence.h"
#import "RACEmptySequence.h"

@implementation RACSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	return [RACDynamicSequence sequenceWithHeadBlock:headBlock tailBlock:tailBlock];
}

+ (RACSequence *)sequenceWithConcatenatedSequences:(NSArray *)seqs {
	return [RACArraySequence sequenceWithArray:seqs offset:0].flatten;
}

#pragma mark Class cluster primitives

- (id)head {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

- (RACSequence *)tail {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

#pragma mark RACStream

+ (instancetype)empty {
	return RACEmptySequence.empty;
}

+ (instancetype)return:(id)value {
	return [RACDynamicSequence sequenceWithHeadBlock:^{
		return value;
	} tailBlock:nil];
}

- (instancetype)bind:(id (^)(id value))block {
	__block RACSequence *(^nextSequence)(RACSequence *, RACSequence *);
	
	nextSequence = [^ RACSequence * (RACSequence *current, RACSequence *valuesSeq) {
		while (current == nil) {
			// We've exhausted the current sequence, create a sequence from the
			// next value.
			id value = valuesSeq.head;

			if (value == nil) {
				// We've exhausted all the sequences.
				return nil;
			}

			valuesSeq = valuesSeq.tail;
			current = block(value);
		}

		NSAssert([current isKindOfClass:RACSequence.class], @"Bind returned an object that is not a sequence: %@", current);

		return [RACDynamicSequence sequenceWithHeadBlock:^{
			return current.head;
		} tailBlock:^{
			return nextSequence(current.tail, valuesSeq);
		}];
	} copy];

	return nextSequence(nil, self);
}

- (instancetype)concat:(id<RACStream>)stream {
	NSParameterAssert(stream != nil);

	return [RACArraySequence sequenceWithArray:@[ self, stream ] offset:0].flatten;
}

#pragma mark Extended methods

- (NSArray *)array {
	NSMutableArray *array = [NSMutableArray array];
	for (id obj in self) {
		[array addObject:obj];
	}

	return [array copy];
}

- (RACSequence *)drop:(NSUInteger)count {
	RACSequence *seq = self;
	for (NSUInteger i = 0; i < count; i++) {
		seq = seq.tail;
	}

	return seq;
}

- (RACSequence *)sequenceByPrependingObject:(id)obj {
	NSParameterAssert(obj != nil);

	return [RACDynamicSequence sequenceWithHeadBlock:^{
		return obj;
	} tailBlock:^{
		return self;
	}];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSCoding

- (Class)classForCoder {
	// All sequences should be archived as RACArraySequences.
	return RACArraySequence.class;
}

- (id)initWithCoder:(NSCoder *)coder {
	if (![self isKindOfClass:RACArraySequence.class]) return [[RACArraySequence alloc] initWithCoder:coder];

	// Decoding is handled in RACArraySequence.
	return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.array forKey:@"array"];
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
	if (state->state == ULONG_MAX) {
		// Enumeration has completed.
		return 0;
	}

	// We need to traverse the sequence itself on repeated calls to this
	// method, so use the 'state' field to track the current head.
	RACSequence *(^getSequence)(void) = ^{
		return (__bridge RACSequence *)(void *)state->state;
	};

	void (^setSequence)(RACSequence *) = ^(RACSequence *sequence) {
		// Release the old sequence and retain the new one.
		CFBridgingRelease((void *)state->state);

		state->state = (unsigned long)CFBridgingRetain(sequence);
	};

	if (state->state == 0) {
		// Since a sequence doesn't mutate, this just needs to be set to
		// something non-NULL.
		state->mutationsPtr = state->extra;

		setSequence(self);
	}

	state->itemsPtr = stackbuf;

	NSUInteger enumeratedCount = 0;
	while (enumeratedCount < len) {
		RACSequence *seq = getSequence();

		// Because the objects in a sequence may be generated lazily, we want to
		// prevent them from being released until the enumerator's used them.
		__autoreleasing id obj = seq.head;
		if (obj == nil) {
			// Release any stored sequence.
			setSequence(nil);
			state->state = ULONG_MAX;

			break;
		}

		stackbuf[enumeratedCount++] = obj;
		setSequence(seq.tail);
	}

	return enumeratedCount;
}

#pragma mark NSObject

- (NSUInteger)hash {
	return [self.head hash];
}

- (BOOL)isEqual:(RACSequence *)seq {
	if (self == seq) return YES;
	if (![seq isKindOfClass:RACSequence.class]) return NO;

	for (id<NSObject> selfObj in self) {
		id<NSObject> seqObj = seq.head;

		// Handles the nil case too.
		if (![seqObj isEqual:selfObj]) return NO;
	}

	// self is now depleted -- the argument should be too.
	return (seq.head == nil);
}

@end
