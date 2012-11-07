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

+ (instancetype)return:(id)value {
	return nil;
}

- (instancetype)flattenMap:(id (^)(id value))block {
	return nil;
}

- (instancetype)concat:(id<RACStream>)stream {
	return nil;
}

#pragma mark Concrete methods

- (instancetype)flatten {
	return [self flattenMap:^(id value) {
		NSAssert([value conformsToProtocol:@protocol(RACStream)], @"Stream %@ being flattened contains an object that is not a stream: %@", self, value);
		return value;
	}];
}

- (instancetype)map:(id (^)(id value))block {
	NSParameterAssert(block != nil);

	return [self flattenMap:^(id value) {
		return [self.class return:block(value)];
	}];
}

- (instancetype)filter:(BOOL (^)(id value))block {
	NSParameterAssert(block != nil);

	return [self flattenMap:^ id (id value) {
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
	return [self flattenMap:^(id value) {
		if (skipped >= skipCount) return [self.class return:value];

		skipped++;
		return self.class.empty;
	}];
}

- (instancetype)take:(NSUInteger)count {
	__block NSUInteger taken = 0;
	return [self flattenMap:^ id (id value) {
		if (taken >= count) return nil;

		taken++;
		return [self.class return:value];
	}];
}

- (instancetype)sequenceMany:(id (^)(void))block {
	NSParameterAssert(block != NULL);

	return [self flattenMap:^(id _) {
		return block();
	}];
}

@end
