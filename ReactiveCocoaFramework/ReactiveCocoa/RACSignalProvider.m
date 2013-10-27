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

#pragma mark Running

- (RACSignal *)signalWithValue:(id)input {
	return self.providerBlock(input);
}

@end

@implementation RACSignalProvider (Operations)

- (instancetype)mapSignals:(RACSignal * (^)(RACSignal *original))block {
	NSCParameterAssert(block != nil);

	return [self.class providerWithBlock:^(id input) {
		return block([self signalWithValue:input]);
	}];
}

- (instancetype)followedBy:(RACSignalProvider *)nextProvider {
	NSCParameterAssert(nextProvider != nil);

	return [self mapSignals:^(RACSignal *input) {
		return [input flattenMap:^(id x) {
			return [nextProvider signalWithValue:x];
		}];
	}];
}

@end
