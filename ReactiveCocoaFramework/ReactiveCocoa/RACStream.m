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

@end

@implementation RACStream (Operations)

- (instancetype)flattenMap:(RACStream * (^)(id value))block {
	RACStream *stream = [self bind:^{
		return ^(id value, BOOL *stop) {
			return block(value);
		};
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -flattenMap:", self.name];
	return stream;
}

- (instancetype)flatten {
	RACStream *stream = [self flattenMap:^(id value) {
		NSAssert([value isKindOfClass:RACStream.class], @"Stream %@ being flattened contains an object that is not a stream: %@", self, value);
		return value;
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -flatten", self.name];
	return stream;
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != nil);

	RACStream *stream = [self flattenMap:^(id value) {
		return [self.class return:block(value)];
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -map:", self.name];
	return stream;
}

- (instancetype)mapReplace:(id)object {
	RACStream *stream = [self map:^(id _) {
		return object;
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -mapReplace: %@", self.name, object];
	return stream;
}

- (instancetype)mapPreviousWithStart:(id)start combine:(id (^)(id previous, id next))combineBlock {
	NSParameterAssert(combineBlock != NULL);
	RACStream *stream = [[self
		scanWithStart:[RACTuple tupleWithObjects:start, nil]
		combine:^(RACTuple *previousTuple, id next) {
			id value = combineBlock(previousTuple[0], next);
			return [RACTuple tupleWithObjects:next ?: RACTupleNil.tupleNil, value ?: RACTupleNil.tupleNil, nil];
		}]
		map:^(RACTuple *tuple) {
			return tuple[1];
		}];

	stream.name = [NSString stringWithFormat:@"[%@] -mapPreviousWithStart: %@ combine:", self.name, start];
	return stream;
}

- (instancetype)filter:(BOOL (^)(id value))block {
	NSParameterAssert(block != nil);

	RACStream *stream = [self flattenMap:^ id (id value) {
		if (block(value)) {
			return [self.class return:value];
		} else {
			return self.class.empty;
		}
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -filter:", self.name];
	return stream;
}

- (instancetype)startWith:(id)value {
	RACStream *stream = [[self.class return:value] concat:self];
	stream.name = [NSString stringWithFormat:@"[%@] -startWith: %@", self.name, value];
	return stream;
}

- (instancetype)skip:(NSUInteger)skipCount {
	RACStream *stream = [self bind:^{
		__block NSUInteger skipped = 0;

		return ^(id value, BOOL *stop) {
			if (skipped >= skipCount) return [self.class return:value];

			skipped++;
			return self.class.empty;
		};
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -skip: %lu", self.name, (unsigned long)skipCount];
	return stream;
}

- (instancetype)take:(NSUInteger)count {
	RACStream *stream = [self bind:^{
		__block NSUInteger taken = 0;

		return ^ id (id value, BOOL *stop) {
			RACStream *result = self.class.empty;

			if (taken < count) result = [self.class return:value];
			if (++taken >= count) *stop = YES;

			return result;
		};
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -take: %lu", self.name, (unsigned long)count];
	return stream;
}

- (instancetype)sequenceMany:(RACStream * (^)(void))block {
	NSParameterAssert(block != NULL);

	RACStream *stream = [self flattenMap:^(id _) {
		return block();
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -sequenceMany:", self.name];
	return stream;
}

+ (instancetype)zip:(id<NSFastEnumeration>)streams {
	RACStream *stream = [self zip:streams reduce:nil];
	stream.name = [NSString stringWithFormat:@"+zip: %@", streams];
	return stream;
}

+ (instancetype)concat:(id<NSFastEnumeration>)streams {
	RACStream *result = self.empty;
	for (RACStream *stream in streams) {
		result = [result concat:stream];
	}

	result.name = [NSString stringWithFormat:@"+concat: %@", streams];
	return result;
}

- (instancetype)scanWithStart:(id)startingValue combine:(id (^)(id running, id next))block {
	NSParameterAssert(block != nil);

	RACStream *stream = [self bind:^{
		__block id running = startingValue;

		return ^(id value, BOOL *stop) {
			running = block(running, value);
			return [self.class return:running];
		};
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -scanWithStart: %@ combine:", self.name, startingValue];
	return stream;
}

- (instancetype)takeUntilBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	RACStream *stream = [self bind:^{
		return ^ id (id value, BOOL *stop) {
			if (predicate(value)) return nil;

			return [self.class return:value];
		};
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -takeUntilBlock:", self.name];
	return stream;
}

- (instancetype)takeWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	RACStream *stream = [self takeUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -takeWhileBlock:", self.name];
	return stream;
}

- (instancetype)skipUntilBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	RACStream *stream = [self bind:^{
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
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -skipUntilBlock:", self.name];
	return stream;
}

- (instancetype)skipWhileBlock:(BOOL (^)(id x))predicate {
	NSParameterAssert(predicate != nil);

	RACStream *stream = [self skipUntilBlock:^ BOOL (id x) {
		return !predicate(x);
	}];

	stream.name = [NSString stringWithFormat:@"[%@] -skipUntilBlock:", self.name];
	return stream;
}

@end
