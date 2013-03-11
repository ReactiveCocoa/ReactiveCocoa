//
//  RACStream.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"
#import "RACBlockTrampoline.h"
#import "RACTuple.h"

@implementation RACStream

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	self.name = @"";
	return self;
}

#pragma mark Abstract methods

+ (instancetype)empty {
	return nil;
}

- (instancetype)bind:(RACStreamBindBlock (^)(void))block {
	return nil;
}

+ (instancetype)return:(id)value {
	return nil;
}

- (instancetype)streamByAppendingStream:(RACStream *)stream {
	return nil;
}

- (instancetype)zippedStreamByCombiningWithStream:(RACStream *)stream {
	return nil;
}

#pragma mark Naming

- (instancetype)setNameWithFormat:(NSString *)format, ... {
#ifdef DEBUG
	NSParameterAssert(format != nil);

	va_list args;
	va_start(args, format);

	NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);

	self.name = str;
#endif
	
	return self;
}

@end

@implementation RACStream (Operations)

- (instancetype)streamByCombiningStreamsFromSignalHandler:(RACStream * (^)(id value))block {
	return [[self bind:^{
		return ^(id value, BOOL *stop) {
			return block(value);
		};
	}] setNameWithFormat:@"[%@] -streamByCombiningStreamsFromSignalHandler:", self.name];
}

- (instancetype)flattened {
	__weak RACStream *stream __attribute__((unused)) = self;
	return [[self streamByCombiningStreamsFromSignalHandler:^(id value) {
		NSAssert([value isKindOfClass:RACStream.class], @"Stream %@ being flattened contains an object that is not a stream: %@", stream, value);
		return value;
	}] setNameWithFormat:@"[%@] -flatten", self.name];
}

- (instancetype)streamWithMappedValuesFromBlock:(id (^)(id value))block {
	NSParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self streamByCombiningStreamsFromSignalHandler:^(id value) {
		return [class return:block(value)];
	}] setNameWithFormat:@"[%@] -streamWithMappedValuesFromBlock:", self.name];
}

- (instancetype)streamByReplacingValuesWithObject:(id)object {
	return [[self streamWithMappedValuesFromBlock:^(id _) {
		return object;
	}] setNameWithFormat:@"[%@] -streamByReplacingValuesWithObject: %@", self.name, object];
}

- (instancetype)streamByCombiningPreviousObjects:(id)start andCurrentObjectsWithCombinationHandler:(id (^)(id previous, id next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	return [[[self
		scanWithStart:[RACTuple tupleWithObjects:start, nil]
		combine:^(RACTuple *previousTuple, id next) {
			id value = combineBlock(previousTuple[0], next);
			return [RACTuple tupleWithObjects:next ?: RACTupleNil.tupleNil, value ?: RACTupleNil.tupleNil, nil];
		}]
		streamWithMappedValuesFromBlock:^(RACTuple *tuple) {
			return tuple[1];
		}]
		setNameWithFormat:@"[%@] -streamByCombiningPreviousObjects: %@ andCurrentObjectsWithCombinationHandler:", self.name, start];
}

- (instancetype)streamByFilteringInObjectsWithValidationHandler:(BOOL (^)(id value))block {
	NSParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self streamByCombiningStreamsFromSignalHandler:^ id (id value) {
		if (block(value)) {
			return [class return:value];
		} else {
			return class.empty;
		}
	}] setNameWithFormat:@"[%@] -streamByFilteringInObjectsWithValidationHandler:", self.name];
}

- (instancetype)streamByReducingObjectsWithIterationHandler:(id)reduceBlock {
	NSParameterAssert(reduceBlock != nil);

	__weak RACStream *stream __attribute__((unused)) = self;
	return [[self streamWithMappedValuesFromBlock:^(RACTuple *t) {
		NSAssert([t isKindOfClass:RACTuple.class], @"Value from stream %@ is not a tuple: %@", stream, t);
		return [RACBlockTrampoline invokeBlock:reduceBlock withArguments:t];
	}] setNameWithFormat:@"[%@] -streamByReducingObjectsWithIterationHandler:", self.name];
}

- (instancetype)streamByPrependingValue:(id)value {
	return [[[self.class return:value]
		streamByAppendingStream:self]
		setNameWithFormat:@"[%@] -streamByPrependingValue: %@", self.name, value];
}

- (instancetype)streamByRemovingObjectsBeforeIndex:(NSUInteger)skipCount {
	Class class = self.class;
	
	return [[self bind:^{
		__block NSUInteger skipped = 0;

		return ^(id value, BOOL *stop) {
			if (skipped >= skipCount) return [class return:value];

			skipped++;
			return class.empty;
		};
	}] setNameWithFormat:@"[%@] -streamByRemovingObjectsBeforeIndex: %lu", self.name, (unsigned long)skipCount];
}

- (instancetype)streamWithObjectsUntilIndex:(NSUInteger)count {
	Class class = self.class;
	
	return [[self bind:^{
		__block NSUInteger taken = 0;

		return ^ id (id value, BOOL *stop) {
			RACStream *result = class.empty;

			if (taken < count) result = [class return:value];
			if (++taken >= count) *stop = YES;

			return result;
		};
	}] setNameWithFormat:@"[%@] -streamWithObjectsUntilIndex: %lu", self.name, (unsigned long)count];
}

- (instancetype)streamByCombiningStreamsWithIterationBlock:(RACStream * (^)(void))block {
	NSParameterAssert(block != NULL);

	return [[self streamByCombiningStreamsFromSignalHandler:^(id _) {
		return block();
	}] setNameWithFormat:@"[%@] -streamByCombiningStreamsWithIterationBlock:", self.name];
}

+ (instancetype)streamByZippingAndCombiningStreams:(id<NSFastEnumeration>)streams {
	RACStream *current = nil;

	// Creates streams of successively larger tuples by combining the input
	// streams one-by-one.
	for (RACStream *stream in streams) {
		// For the first stream, just wrap its values in a RACTuple. That way,
		// if only one stream is given, the result is still a stream of tuples.
		if (current == nil) {
			current = [stream streamWithMappedValuesFromBlock:^(id x) {
				return RACTuplePack(x);
			}];

			continue;
		}

		// `zipped` will contain tuples of:
		//
		//   ((current value), stream value)
		RACStream *zipped = [current zippedStreamByCombiningWithStream:stream];
		
		// Then, because `current` itself contained tuples of the previous
		// streams, we need to flatten each value into a new tuple.
		//
		// In other words, this transforms a stream of:
		//
		//	 ((s1, s2, …), sN)
		//
		// … into a stream of:
		//
		//	 (s1, s2, …, sN)
		//
		// … by expanding the inner tuple.
		current = [zipped streamWithMappedValuesFromBlock:^(RACTuple *twoTuple) {
			RACTuple *previousTuple = twoTuple[0];
			return [previousTuple tupleByAddingObject:twoTuple[1]];
		}];
	}

	if (current == nil) return [self empty];
	return [current setNameWithFormat:@"+streamByZippingStreams: %@", streams];
}

+ (instancetype)streamByZippingStreams:(id<NSFastEnumeration>)streams
andReducingObjectsWithIterationHandler:(id)reduceBlock {
	NSParameterAssert(reduceBlock != nil);

	RACStream *result = [self streamByZippingAndCombiningStreams:streams];

	// Although we assert this condition above, older versions of this method
	// supported this argument being nil. Avoid crashing Release builds of
	// apps that depended on that.
	if (reduceBlock != nil) result = [result streamByReducingObjectsWithIterationHandler:reduceBlock];

	return [result setNameWithFormat:@"+streamByZippingStreams: %@ andReducingObjectsWithIterationHandler:", streams];
}

+ (instancetype)streamByAppendingStreams:(id<NSFastEnumeration>)streams {
	RACStream *result = self.empty;
	for (RACStream *stream in streams) {
		result = [result streamByAppendingStream:stream];
	}

	return [result setNameWithFormat:@"+streamByAppendingStream: %@", streams];
}

- (instancetype)scanWithStart:(id)startingValue
					  combine:(id (^)(id running, id next))block {
	NSParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self bind:^{
		__block id running = startingValue;

		return ^(id value, BOOL *stop) {
			running = block(running, value);
			return [class return:running];
		};
	}] setNameWithFormat:@"[%@] -scanWithStart: %@ combine:", self.name, startingValue];
}

- (instancetype)streamByCombiningObjectsUntilPredicate:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	Class class = self.class;
	
	return [[self bind:^{
		return ^ id (id value, BOOL *stop) {
			if (predicate(value)) return nil;

			return [class return:value];
		};
	}] setNameWithFormat:@"[%@] -streamByCombiningObjectsUntilPredicate:", self.name];
}

- (instancetype)streamByCombiningObjectsWhilePredicate:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self streamByCombiningObjectsUntilPredicate:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -streamByCombiningObjectsUntilPredicate:", self.name];
}

- (instancetype)streamByRemovingObjectsUntilPredicate:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	Class class = self.class;
	
	return [[self bind:^{
		__block BOOL skipping = YES;

		return ^ id (id value, BOOL *stop) {
			if (skipping) {
				if (predicate(value)) {
					skipping = NO;
				} else {
					return class.empty;
				}
			}

			return [class return:value];
		};
	}] setNameWithFormat:@"[%@] -streamByRemovingObjectsUntilPredicate:", self.name];
}

- (instancetype)streamByRemovingObjectsWhilePredicate:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self streamByRemovingObjectsUntilPredicate:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -streamByRemovingObjectsUntilPredicate:", self.name];
}

@end
