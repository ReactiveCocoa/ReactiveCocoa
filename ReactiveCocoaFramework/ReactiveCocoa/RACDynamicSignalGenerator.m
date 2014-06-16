//
//  RACDynamicSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignalGenerator.h"
#import "EXTScope.h"

@interface RACDynamicSignalGenerator ()

@property (nonatomic, copy, readonly) RACSignal * (^block)(id);

@end

@implementation RACDynamicSignalGenerator

#pragma mark Lifecycle

+ (instancetype)generatorWithBlock:(RACSignal * (^)(id input))block {
	return [[self alloc] initWithBlock:block];
}

+ (instancetype)generatorWithReflexiveBlock:(RACSignal * (^)(id input, RACDynamicSignalGenerator *generator))block {
	RACDynamicSignalGenerator *generator = [self alloc];

	// We don't need a real weak reference for this, because it's basically
	// impossible for the generator to deallocate while the block is being
	// invoked. (Also, they're expensive.)
	@unsafeify(generator);

	return [generator initWithBlock:^(id input) {
		@strongify(generator);
		return block(input, generator);
	}];
}

- (id)initWithBlock:(RACSignal * (^)(id input))block {
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_block = [block copy];

	return self;
}

#pragma mark RACSignalGenerator

- (RACSignal *)signalWithValue:(id)input {
	RACSignal *signal = self.block(input);
	NSCAssert(signal != nil, @"Generator %@ returned a nil signal", self);

	return signal;
}

@end
