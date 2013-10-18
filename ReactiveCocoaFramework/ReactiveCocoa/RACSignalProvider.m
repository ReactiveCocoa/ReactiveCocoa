//
//  RACSignalProvider.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalProvider.h"
#import "RACSignal+Operations.h"

@interface RACSignalProvider ()

// The block implementing the receiver's logic.
@property (nonatomic, copy, readonly) RACSignal * (^providerBlock)(id);

@end

@implementation RACSignalProvider

#pragma mark Lifecycle

- (id)initWithBlock:(RACSignal * (^)(id input))block {
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_providerBlock = [block copy];

	return self;
}

#pragma mark Arrow composition

- (instancetype)pullback:(RACSignalProvider *)firstProvider {
	NSCParameterAssert(firstProvider != nil);

	return [[self.class alloc] initWithBlock:^(id input) {
		return [[firstProvider
			provide:input]
			flattenMap:^(id x) {
				return [self provide:x];
			}];
	}];
}

#pragma mark Running

- (RACSignal *)provide:(id)input {
	return self.providerBlock(input);
}

@end
