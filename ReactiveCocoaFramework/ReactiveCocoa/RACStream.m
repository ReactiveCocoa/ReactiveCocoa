//
//  RACStream.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-31.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACStream.h"

@concreteprotocol(RACStream)

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

- (instancetype)startWith:(id)value {
	return [[self.class return:value] concat:self];
}

@end
