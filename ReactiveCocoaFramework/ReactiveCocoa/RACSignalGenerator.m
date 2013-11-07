//
//  RACSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"
#import "RACDynamicSignalGenerator.h"

@implementation RACSignalGenerator

#pragma mark Lifecycle

+ (RACSignalGenerator *)generatorWithBlock:(RACSignal * (^)(id input))block {
	return [RACDynamicSignalGenerator generatorWithBlock:block];
}

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	NSCAssert(NO, @"Subclasses must override this method");
	return nil;
}

@end
