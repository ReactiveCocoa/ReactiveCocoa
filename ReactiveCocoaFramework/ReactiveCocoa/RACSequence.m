//
//  RACSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"
#import "RACArraySequence.h"
#import "RACDisposable.h"
#import "RACDynamicSequence.h"
#import "RACEagerSequence.h"
#import "RACEmptySequence.h"
#import "RACScheduler.h"
#import "RACSubject.h"
#import "RACSignal.h"
#import "RACTuple.h"
#import "RACBlockTrampoline.h"
#import <libkern/OSAtomic.h>

@interface RACSequence ()

// Performs one iteration of lazy binding, passing through values from `current`
// until the sequence is exhausted, then recursively binding the remaining
// values in the receiver.
//
// Returns a new sequence which contains `current`, followed by the combined
// result of all applications of `block` to the remaining values in the receiver.
- (instancetype)bind:(RACStreamBindBlock)block passingThroughValuesFromSequence:(RACSequence *)current;

@end

@implementation RACSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
	RACSequence *sequence = [RACDynamicSequence sequenceWithHeadBlock:headBlock tailBlock:tailBlock];
	sequence.name = @"+sequenceWithHeadBlock:tailBlock:";
	return sequence;
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
	RACSequence *sequence = [RACDynamicSequence sequenceWithHeadBlock:^{
		return value;
	} tailBlock:nil];

	sequence.name = [NSString stringWithFormat:@"+return: %@", value];
	return sequence;
}

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	RACStreamBindBlock bindBlock = block();
	RACSequence *sequence = [self bind:bindBlock passingThroughValuesFromSequence:nil];
	sequence.name = [NSString stringWithFormat:@"[%@] -bind:", self.name];
	return sequence;
}

- (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {
	RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
		RACSequence *valuesSeq = self;
		RACSequence *current = passthroughSequence;

		BOOL stop = NO;
		while (current.head == nil) {
			if (stop) return nil;

			// We've exhausted the current sequence, create a sequence from the
			// next value.
			id value = valuesSeq.head;

			if (value == nil) {
				// We've exhausted all the sequences.
				return nil;
			}

			current = (id)bindBlock(value, &stop);
			if (current == nil) return nil;

			valuesSeq = valuesSeq.tail;
		}

		NSAssert([current isKindOfClass:RACSequence.class], @"-bind: block returned an object that is not a sequence: %@", current);

		return [RACTuple tupleWithObjects:(valuesSeq ?: RACTupleNil.tupleNil), (current ?: RACTupleNil.tupleNil), @(stop), nil];
	} headBlock:^ id (RACTuple *sequences) {
		RACSequence *current = sequences[1];
		return current.head;
	} tailBlock:^ id (RACTuple *sequences) {
		NSNumber *stop = sequences[2];
		if (sequences == nil || stop.boolValue) return nil;

		RACSequence *valuesSeq = sequences[0];
		RACSequence *current = sequences[1];
		return [valuesSeq bind:bindBlock passingThroughValuesFromSequence:current.tail];
	}];

	sequence.name = self.name;
	return sequence;
}

- (instancetype)concat:(RACStream *)stream {
	NSParameterAssert(stream != nil);

	RACSequence *sequence = [RACArraySequence sequenceWithArray:@[ self, stream ] offset:0].flatten;
	sequence.name = [NSString stringWithFormat:@"[%@] -concat: %@", self.name, stream];
	return sequence;
}

+ (instancetype)zip:(id<NSFastEnumeration>)sequences reduce:(id)reduceBlock {
	NSMutableArray *sequencesArray = [NSMutableArray array];
	for (RACSequence *sequence in sequences) {
		[sequencesArray addObject:sequence];
	}
	if (sequencesArray.count == 0) return self.empty;

	RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^ id {
		NSMutableArray *heads = [NSMutableArray arrayWithCapacity:sequencesArray.count];
		for (RACSequence *sequence in sequencesArray) {
			id head = sequence.head;
			if (head == nil) {
				return nil;
			}
			[heads addObject:head];
		}
		if (reduceBlock == NULL) {
			return [RACTuple tupleWithObjectsFromArray:heads];
		} else {
			return [RACBlockTrampoline invokeBlock:reduceBlock withArguments:heads];
		}
	} tailBlock:^ RACSequence * {
		NSMutableArray *tails = [NSMutableArray arrayWithCapacity:sequencesArray.count];
		for (RACSequence *sequence in sequencesArray) {
			RACSequence *tail = sequence.tail;
			if (tail == nil || tail == RACSequence.empty) {
				return tail;
			}
			[tails addObject:tail];
		}
		return [RACSequence zip:tails reduce:reduceBlock];
	}];

	sequence.name = [NSString stringWithFormat:@"+zip: %@ reduce:", sequencesArray];
	return sequence;
}

#pragma mark Extended methods

- (NSArray *)array {
	NSMutableArray *array = [NSMutableArray array];
	for (id obj in self) {
		[array addObject:obj];
	}

	return [array copy];
}

- (RACSignal *)signal {
	RACSignal *signal = [self signalWithScheduler:[RACScheduler scheduler]];
	signal.name = [NSString stringWithFormat:@"[%@] -signal", self.name];
	return signal;
}

- (RACSignal *)signalWithScheduler:(RACScheduler *)scheduler {
	return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block RACSequence *sequence = self;

		return [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
			if (sequence.head == nil) {
				[subscriber sendCompleted];
				return;
			}

			[subscriber sendNext:sequence.head];

			sequence = sequence.tail;
			reschedule();
		}];
	} name:@"[%@] -signalWithScheduler:", self.name];
}

- (RACSequence *)eagerSequence {
	return [RACEagerSequence sequenceWithArray:self.array offset:0];
}

- (RACSequence *)lazySequence {
	return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSCoding

- (Class)classForCoder {
	// Most sequences should be archived as RACArraySequences.
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

		seq = seq.tail;
	}

	// self is now depleted -- the argument should be too.
	return (seq.head == nil);
}

@end
