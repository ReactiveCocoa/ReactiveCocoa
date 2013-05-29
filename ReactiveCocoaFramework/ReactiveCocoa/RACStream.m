//
//  RACStream.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"
#import "NSObject+RACDescription.h"
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

- (instancetype)concat:(RACStream *)stream {
	return nil;
}

- (instancetype)zipWith:(RACStream *)stream {
	return nil;
}

#pragma mark Naming

- (instancetype)setNameWithFormat:(NSString *)format, ... {
#ifdef DEBUG
	NSCParameterAssert(format != nil);

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

- (instancetype)flattenMap:(RACStream * (^)(id value))block {
	return [[self bind:^{
		return ^(id value, BOOL *stop) {
			return block(value);
		};
	}] setNameWithFormat:@"[%@] -flattenMap:", self.name];
}

- (instancetype)flatten {
	__weak RACStream *stream __attribute__((unused)) = self;
	return [[self flattenMap:^(id value) {
		NSCAssert([value isKindOfClass:RACStream.class], @"Stream %@ being flattened contains an object that is not a stream: %@", stream, value);
		return value;
	}] setNameWithFormat:@"[%@] -flatten", self.name];
}

- (instancetype)map:(id (^)(id value))block {
	NSCParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self flattenMap:^(id value) {
		return [class return:block(value)];
	}] setNameWithFormat:@"[%@] -map:", self.name];
}

- (instancetype)mapReplace:(id)object {
	return [[self map:^(id _) {
		return object;
	}] setNameWithFormat:@"[%@] -mapReplace: %@", self.name, [object rac_description]];
}

- (instancetype)mapPreviousWithStart:(id)start combine:(id (^)(id previous, id next))combineBlock {
	NSCParameterAssert(combineBlock != NULL);
	return [[[self
		scanWithStart:[RACTuple tupleWithObjects:start, nil]
		combine:^(RACTuple *previousTuple, id next) {
			id value = combineBlock(previousTuple[0], next);
			return [RACTuple tupleWithObjects:next ?: RACTupleNil.tupleNil, value ?: RACTupleNil.tupleNil, nil];
		}]
		map:^(RACTuple *tuple) {
			return tuple[1];
		}]
		setNameWithFormat:@"[%@] -mapPreviousWithStart: %@ combine:", self.name, [start rac_description]];
}

- (instancetype)filter:(BOOL (^)(id value))block {
	NSCParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self flattenMap:^ id (id value) {
		if (block(value)) {
			return [class return:value];
		} else {
			return class.empty;
		}
	}] setNameWithFormat:@"[%@] -filter:", self.name];
}

- (instancetype)ignore:(id)value {
	return [[self filter:^ BOOL (id innerValue) {
		return innerValue != value && ![innerValue isEqual:value];
	}] setNameWithFormat:@"[%@] -ignore: %@", self.name, [value rac_description]];
}

- (instancetype)reduceEach:(id)reduceBlock {
	NSCParameterAssert(reduceBlock != nil);

	__weak RACStream *stream __attribute__((unused)) = self;
	return [[self map:^(RACTuple *t) {
		NSCAssert([t isKindOfClass:RACTuple.class], @"Value from stream %@ is not a tuple: %@", stream, t);
		return [RACBlockTrampoline invokeBlock:reduceBlock withArguments:t];
	}] setNameWithFormat:@"[%@] -reduceEach:", self.name];
}

- (instancetype)startWith:(id)value {
	return [[[self.class return:value]
		concat:self]
		setNameWithFormat:@"[%@] -startWith: %@", self.name, [value rac_description]];
}

- (instancetype)skip:(NSUInteger)skipCount {
	Class class = self.class;
	
	return [[self bind:^{
		__block NSUInteger skipped = 0;

		return ^(id value, BOOL *stop) {
			if (skipped >= skipCount) return [class return:value];

			skipped++;
			return class.empty;
		};
	}] setNameWithFormat:@"[%@] -skip: %lu", self.name, (unsigned long)skipCount];
}

- (instancetype)take:(NSUInteger)count {
	Class class = self.class;
	
	return [[self bind:^{
		__block NSUInteger taken = 0;

		return ^ id (id value, BOOL *stop) {
			RACStream *result = class.empty;

			if (taken < count) result = [class return:value];
			if (++taken >= count) *stop = YES;

			return result;
		};
	}] setNameWithFormat:@"[%@] -take: %lu", self.name, (unsigned long)count];
}

- (instancetype)sequenceMany:(RACStream * (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[self flattenMap:^(id _) {
		return block();
	}] setNameWithFormat:@"[%@] -sequenceMany:", self.name];
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams {
	RACStream *current = nil;

	// Creates streams of successively larger tuples by combining the input
	// streams one-by-one.
	for (RACStream *stream in streams) {
		// For the first stream, just wrap its values in a RACTuple. That way,
		// if only one stream is given, the result is still a stream of tuples.
		if (current == nil) {
			current = [stream map:^(id x) {
				return RACTuplePack(x);
			}];

			continue;
		}

		// `zipped` will contain tuples of:
		//
		//   ((current value), stream value)
		RACStream *zipped = [current zipWith:stream];
		
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
		current = [zipped map:^(RACTuple *twoTuple) {
			RACTuple *previousTuple = twoTuple[0];
			return [previousTuple tupleByAddingObject:twoTuple[1]];
		}];
	}

	if (current == nil) return [self empty];
	return [current setNameWithFormat:@"+zip: %@", streams];
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id)reduceBlock {
	NSCParameterAssert(reduceBlock != nil);

	RACStream *result = [self zip:streams];

	// Although we assert this condition above, older versions of this method
	// supported this argument being nil. Avoid crashing Release builds of
	// apps that depended on that.
	if (reduceBlock != nil) result = [result reduceEach:reduceBlock];

	return [result setNameWithFormat:@"+zip: %@ reduce:", streams];
}

+ (instancetype)concat:(id<NSFastEnumeration>)streams {
	RACStream *result = self.empty;
	for (RACStream *stream in streams) {
		result = [result concat:stream];
	}

	return [result setNameWithFormat:@"+concat: %@", streams];
}

- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block {
	NSCParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self bind:^{
		__block id running = startingValue;

		return ^(id value, BOOL *stop) {
			running = block(running, value);
			return [class return:running];
		};
	}] setNameWithFormat:@"[%@] -scanWithStart: %@ combine:", self.name, [startingValue rac_description]];
}

- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate {
	NSCParameterAssert(predicate != nil);

	Class class = self.class;
	
	return [[self bind:^{
		return ^ id (id value, BOOL *stop) {
			if (predicate(value)) return nil;

			return [class return:value];
		};
	}] setNameWithFormat:@"[%@] -takeUntilBlock:", self.name];
}

- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate {
	NSCParameterAssert(predicate != nil);

	return [[self takeUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -takeWhileBlock:", self.name];
}

- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate {
	NSCParameterAssert(predicate != nil);

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
	}] setNameWithFormat:@"[%@] -skipUntilBlock:", self.name];
}

- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate {
	NSCParameterAssert(predicate != nil);

	return [[self skipUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -skipUntilBlock:", self.name];
}

@end
