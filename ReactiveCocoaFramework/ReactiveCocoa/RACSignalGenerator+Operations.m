//
//  RACSignalGenerator+Operations.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator+Operations.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"

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
