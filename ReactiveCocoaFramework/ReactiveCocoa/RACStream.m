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

- (instancetype)bind:(id (^)(id value))block {
	return nil;
}

- (instancetype)concat:(id<RACStream>)stream {
	return nil;
}

#pragma mark Concrete methods

- (instancetype)flatten {
	return [self bind:^(id value) {
		NSAssert([value conformsToProtocol:@protocol(RACStream)], @"Stream %@ being flattened contains an object that is not a stream: %@", self, value);
		return value;
	}];
}

- (instancetype)map:(id (^)(id value))block {
	return [self bind:^(id value) {
		return [self.class return:block(value)];
	}];
}

- (instancetype)filter:(BOOL (^)(id value))block {
	return [self bind:^(id value) {
		if (block(value)) {
			return [self.class return:value];
		} else {
			return self.class.empty;
		}
	}];
}

- (instancetype)startWith:(id)value {
	return [[self.class return:value] concat:self];
}

- (instancetype)skip:(NSUInteger)skipCount {
	__block NSUInteger skipped = 0;
	return [self bind:^(id value) {
		if (skipped >= skipCount) return [self.class return:value];

		skipped++;
		return self.class.empty;
	}];
}

- (instancetype)take:(NSUInteger)count {
	__block NSUInteger taken = 0;
	return [self bind:^(id value) {
		if (taken >= count) return self.class.empty;

		taken++;
		return [self.class return:value];
	}];
}

@end
