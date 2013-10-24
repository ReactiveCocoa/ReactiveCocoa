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

+ (instancetype)providerWithSignal:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	return [self providerWithBlock:^(id _) {
		return signal;
	}];
}

+ (instancetype)returnProvider {
	static id singleton;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		singleton = [self providerWithBlock:^(id input) {
			return [RACSignal return:input];
		}];
	});

	return singleton;
}

#pragma mark Arrow composition

- (instancetype)followedBy:(RACSignalProvider *)nextProvider {
	NSCParameterAssert(nextProvider != nil);

	return [self.class providerWithBlock:^(id input) {
		return [[self
			provide:input]
			flattenMap:^(id intermediate) {
				return [nextProvider provide:intermediate];
			}];
	}];
}

#pragma mark Running

- (RACSignal *)provide:(id)input {
	return self.providerBlock(input);
}

@end
