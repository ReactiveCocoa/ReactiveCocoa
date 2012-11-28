//
//  RACStream.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"

@concreteprotocol(RACStream)

#pragma mark Required primitives

+ (instancetype)empty {
	return nil;
}

- (instancetype)bind:(id (^)(id value, BOOL *stop))block {
	return nil;
}

+ (instancetype)return:(id)value {
	return nil;
}

- (instancetype)concat:(id<RACStream>)stream {
	return nil;
}

+ (instancetype)zip:(NSArray *)streams reduce:(id)reduceBlock {
	return nil;
}

- (NSArray *)toArray {
  return nil;
}

#pragma mark Concrete methods

- (instancetype)flattenMap:(id (^)(id value))block {
	return [self bind:^(id value, BOOL *stop) {
		return block(value);
	}];
}

- (instancetype)flatten {
	return [self bind:^(id value, BOOL *stop) {
		NSAssert([value conformsToProtocol:@protocol(RACStream)], @"Stream %@ being flattened contains an object that is not a stream: %@", self, value);
		return value;
	}];
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != nil);

	return [self bind:^(id value, BOOL *stop) {
		return [self.class return:block(value)];
	}];
}

- (instancetype)filter:(BOOL (^)(id value))block {
	NSParameterAssert(block != nil);

	return [self bind:^ id (id value, BOOL *stop) {
		if (block(value)) {
			return [self.class return:value];
		} else {
			return [self.class empty];
		}
	}];
}

- (instancetype)startWith:(id)value {
	return [[self.class return:value] concat:self];
}

- (instancetype)skip:(NSUInteger)skipCount {
	__block NSUInteger skipped = 0;
	return [self bind:^(id value, BOOL *stop) {
		if (skipped >= skipCount) return [self.class return:value];

		skipped++;
		return self.class.empty;
	}];
}

- (instancetype)take:(NSUInteger)count {
	__block NSUInteger taken = 0;
	return [self bind:^ id (id value, BOOL *stop) {
		id<RACStream> result = self.class.empty;

		if (taken < count) result = [self.class return:value];
		if (++taken >= count) *stop = YES;

		return result;
	}];
}

- (instancetype)sequenceMany:(id (^)(void))block {
	NSParameterAssert(block != NULL);

	return [self bind:^(id _, BOOL *stop) {
		return block();
	}];
}

+ (instancetype)zip:(NSArray *)streams {
	return [self zip:streams reduce:nil];
}

@end
