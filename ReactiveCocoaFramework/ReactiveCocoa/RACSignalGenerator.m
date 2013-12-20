//
//  RACSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"

@implementation RACSignalGenerator

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	NSCAssert(NO, @"Subclasses must override this method");
	return nil;
}

@end

@implementation RACSignal (RACSignalGeneratorAdditions)

- (RACSignalGenerator *)signalGenerator {
	return [RACDynamicSignalGenerator generatorWithBlock:^(id _) {
		return self;
	}];
}

@end

@implementation RACSignalGenerator (Operations)

- (RACSignalGenerator *)postcompose:(RACSignalGenerator *)otherGenerator {
	NSCParameterAssert(otherGenerator != nil);

	return [RACDynamicSignalGenerator generatorWithBlock:^(id input) {
		return [[self
			signalWithValue:input]
			flattenMap:^(id intermediateValue) {
				return [otherGenerator signalWithValue:intermediateValue];
			}];
	}];
}

@end
