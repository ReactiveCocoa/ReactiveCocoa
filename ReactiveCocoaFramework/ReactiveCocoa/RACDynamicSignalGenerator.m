//
//  RACDynamicSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignalGenerator.h"

@interface RACDynamicSignalGenerator ()

@property (nonatomic, copy, readonly) RACSignal * (^block)(id);

@end

@implementation RACDynamicSignalGenerator

#pragma mark Lifecycle

+ (instancetype)generatorWithBlock:(RACSignal * (^)(id input))block {
	NSCParameterAssert(block != nil);

	RACDynamicSignalGenerator *generator = [[self alloc] init];
	generator->_block = [block copy];
	return generator;
}

#pragma mark RACSignalGenerator

- (RACSignal *)signalWithValue:(id)input {
	return self.block(input);
}

@end
