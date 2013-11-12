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

- (id)initWithBlock:(RACSignal * (^)(id input))block {
	NSCParameterAssert(block != nil);

	self = [super init];
	if (self == nil) return nil;

	_block = [block copy];

	return self;
}

#pragma mark RACSignalGenerator

- (RACSignal *)signalWithValue:(id)input {
	return self.block(input);
}

@end
