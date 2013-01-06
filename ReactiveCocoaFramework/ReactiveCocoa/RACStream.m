//
//  RACStream.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"
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

+ (instancetype)zip:(id<NSFastEnumeration>)streams reduce:(id)reduceBlock {
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

- (instancetype)flattenMap:(RACStream * (^)(id value))block {
	return [[self bind:^{
		return ^(id value, BOOL *stop) {
			return block(value);
		};
	}] setNameWithFormat:@"[%@] -flattenMap:", self.name];
}

- (instancetype)flatten {
	return [[self flattenMap:^(id value) {
		NSAssert([value isKindOfClass:RACStream.class], @"Stream %@ being flattened contains an object that is not a stream: %@", self, value);
		return value;
	}] setNameWithFormat:@"[%@] -flatten", self.name];
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != nil);

	return [[self flattenMap:^(id value) {
		return [self.class return:block(value)];
	}] setNameWithFormat:@"[%@] -map:", self.name];
}

- (instancetype)mapReplace:(id)object {
	return [[self map:^(id _) {
		return object;
	}] setNameWithFormat:@"[%@] -mapReplace: %@", self.name, object];
}

- (instancetype)mapPreviousWithStart:(id)start combine:(id (^)(id previous, id next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	return [[[self
		scanWithStart:[RACTuple tupleWithObjects:start, nil]
		combine:^(RACTuple *previousTuple, id next) {
			id value = combineBlock(previousTuple[0], next);
			return [RACTuple tupleWithObjects:next ?: RACTupleNil.tupleNil, value ?: RACTupleNil.tupleNil, nil];
		}]
		map:^(RACTuple *tuple) {
			return tuple[1];
		}]
		setNameWithFormat:@"[%@] -mapPreviousWithStart: %@ combine:", self.name, start];
}

- (instancetype)filter:(BOOL (^)(id value))block {
	NSParameterAssert(block != nil);

	return [[self flattenMap:^ id (id value) {
		if (block(value)) {
			return [self.class return:value];
		} else {
			return self.class.empty;
		}
	}] setNameWithFormat:@"[%@] -filter:", self.name];
}

- (instancetype)startWith:(id)value {
	return [[[self.class return:value]
		concat:self]
		setNameWithFormat:@"[%@] -startWith: %@", self.name, value];
}

- (instancetype)skip:(NSUInteger)skipCount {
	return [[self bind:^{
		__block NSUInteger skipped = 0;

		return ^(id value, BOOL *stop) {
			if (skipped >= skipCount) return [self.class return:value];

			skipped++;
			return self.class.empty;
		};
	}] setNameWithFormat:@"[%@] -skip: %lu", self.name, (unsigned long)skipCount];
}

- (instancetype)take:(NSUInteger)count {
	return [[self bind:^{
		__block NSUInteger taken = 0;

		return ^ id (id value, BOOL *stop) {
			RACStream *result = self.class.empty;

			if (taken < count) result = [self.class return:value];
			if (++taken >= count) *stop = YES;

			return result;
		};
	}] setNameWithFormat:@"[%@] -take: %lu", self.name, (unsigned long)count];
}

- (instancetype)sequenceMany:(RACStream * (^)(void))block {
	NSParameterAssert(block != NULL);

	return [[self flattenMap:^(id _) {
		return block();
	}] setNameWithFormat:@"[%@] -sequenceMany:", self.name];
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams {
	return [[self zip:streams reduce:nil] setNameWithFormat:@"+zip: %@", streams];
}

+ (instancetype)concat:(id<NSFastEnumeration>)streams {
	RACStream *result = self.empty;
	for (RACStream *stream in streams) {
		result = [result concat:stream];
	}

	return [result setNameWithFormat:@"+concat: %@", streams];
}

- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block {
	NSParameterAssert(block != nil);

	return [[self bind:^{
		__block id running = startingValue;

		return ^(id value, BOOL *stop) {
			running = block(running, value);
			return [self.class return:running];
		};
	}] setNameWithFormat:@"[%@] -scanWithStart: %@ combine:", self.name, startingValue];
}

- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self bind:^{
		return ^ id (id value, BOOL *stop) {
			if (predicate(value)) return nil;

			return [self.class return:value];
		};
	}] setNameWithFormat:@"[%@] -takeUntilBlock:", self.name];
}

- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self takeUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -takeWhileBlock:", self.name];
}

- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self bind:^{
		__block BOOL skipping = YES;

		return ^ id (id value, BOOL *stop) {
			if (skipping) {
				if (predicate(value)) {
					skipping = NO;
				} else {
					return self.class.empty;
				}
			}

			return [self.class return:value];
		};
	}] setNameWithFormat:@"[%@] -skipUntilBlock:", self.name];
}

- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	return [[self skipUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}] setNameWithFormat:@"[%@] -skipUntilBlock:", self.name];
}

@end
