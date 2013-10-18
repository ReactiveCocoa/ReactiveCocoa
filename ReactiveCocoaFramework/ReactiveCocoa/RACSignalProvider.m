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

+ (instancetype)providerWithBlock:(RACSignal * (^)(id input))block {
	NSCParameterAssert(block != nil);

	RACSignalProvider *provider = [[self alloc] init];
	provider->_providerBlock = [block copy];
	return provider;
}

#pragma mark Arrow composition

- (instancetype)pullback:(RACSignalProvider *)firstProvider {
	NSCParameterAssert(firstProvider != nil);

	return [self.class providerWithBlock:^(id input) {
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
