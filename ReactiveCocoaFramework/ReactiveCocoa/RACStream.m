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
			id stream = block(value);
			NSCAssert(stream != nil, @"Expected non-nil stream to be returned from -flattenMap:");

			return stream;
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

- (instancetype)combinePreviousWithStart:(id)start reduce:(id (^)(id previous, id next))reduceBlock {
	NSCParameterAssert(reduceBlock != NULL);
	return [[[self
		scanWithStart:[RACTuple tupleWithObjects:start, nil]
		reduce:^(RACTuple *previousTuple, id next) {
			id value = reduceBlock(previousTuple[0], next);
			return [RACTuple tupleWithObjects:next ?: RACTupleNil.tupleNil, value ?: RACTupleNil.tupleNil, nil];
		}]
		map:^(RACTuple *tuple) {
			return tuple[1];
		}]
		setNameWithFormat:@"[%@] -combinePreviousWithStart: %@ reduce:", self.name, [start rac_description]];
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

- (instancetype)reduceEach:(id (^)())reduceBlock {
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

+ (instancetype)join:(id<NSFastEnumeration>)streams block:(RACStream * (^)(id, id))block {
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

		current = block(current, stream);
	}

	if (current == nil) return [self empty];

	return [current map:^(RACTuple *xs) {
		// Right now, each value is contained in its own tuple, sorta like:
		//
		// (((1), 2), 3)
		//
		// We need to unwrap all the layers and create a tuple out of the result.
		NSMutableArray *values = [[NSMutableArray alloc] init];

		while (xs != nil) {
			[values insertObject:xs.last ?: RACTupleNil.tupleNil atIndex:0];
			xs = (xs.count > 1 ? xs.first : nil);
		}

		return [RACTuple tupleWithObjectsFromArray:values];
	}];
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams {
	return [[self join:streams block:^(RACStream *left, RACStream *right) {
		return [left zipWith:right];
	}] setNameWithFormat:@"+zip: %@", streams];
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id (^)())reduceBlock {
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

- (instancetype)scanWithStart:(id)startingValue reduce:(id (^)(id running, id next))block {
	NSCParameterAssert(block != nil);

	Class class = self.class;
	
	return [[self bind:^{
		__block id running = startingValue;

		return ^(id value, BOOL *stop) {
			running = block(running, value);
			return [class return:running];
		};
	}] setNameWithFormat:@"[%@] -scanWithStart: %@ reduce:", self.name, [startingValue rac_description]];
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

- (instancetype)distinctUntilChanged {
	Class class = self.class;

	return [[self bind:^{
		__block id lastValue = nil;
		__block BOOL initial = YES;

		return ^(id x, BOOL *stop) {
			if (!initial && (lastValue == x || [x isEqual:lastValue])) return [class empty];

			initial = NO;
			lastValue = x;
			return [class return:x];
		};
	}] setNameWithFormat:@"[%@] -distinctUntilChanged", self.name];
}

@end

@implementation RACStream (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)sequenceMany:(RACStream * (^)(void))block {
	NSCParameterAssert(block != NULL);

	return [[self flattenMap:^(id _) {
		return block();
	}] setNameWithFormat:@"[%@] -sequenceMany:", self.name];
}

- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block {
	return [self scanWithStart:startingValue reduce:block];
}

- (instancetype)mapPreviousWithStart:(id)start reduce:(id (^)(id previous, id current))combineBlock {
	return [self combinePreviousWithStart:start reduce:combineBlock];
}

#pragma clang diagnostic pop

@end
