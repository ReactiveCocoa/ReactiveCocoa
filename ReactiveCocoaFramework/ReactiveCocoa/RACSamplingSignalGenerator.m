//
//  RACSamplingSignalGenerator.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-27.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSamplingSignalGenerator.h"

#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACEvent.h"
#import "RACSignal+Operations.h"
#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACTuple.h"

@interface RACSamplingSignalGenerator ()

// The latest event sampled from the input signal, or `nil` if nothing has been
// received yet.
@property (atomic, copy, readonly) RACEvent *sampledEvent;

// Generates signals given a tuple of the receiver's input value, and the
// sampled value.
@property (nonatomic, strong, readonly) RACSignalGenerator *underlyingGenerator;

@end

@implementation RACSamplingSignalGenerator

#pragma mark Lifecycle

+ (instancetype)generatorBySampling:(RACSignal *)signal forGenerator:(RACSignalGenerator *)underlyingGenerator {
	return [[self alloc] initWithGenerator:underlyingGenerator sampledSignal:signal];
}

- (instancetype)initWithGenerator:(RACSignalGenerator *)underlyingGenerator sampledSignal:(RACSignal *)signal {
	NSCParameterAssert(underlyingGenerator != nil);
	NSCParameterAssert(signal != nil);

	self = [super init];
	if (self == nil) return nil;

	_underlyingGenerator = underlyingGenerator;

	RAC(self, sampledEvent) = [signal materialize];

	return self;
}

#pragma mark Generation

- (RACSignal *)signalWithValue:(id)input {
	return [[[[[RACObserve(self, sampledEvent)
		ignore:nil]
		take:1]
		dematerialize]
		flattenMap:^(id sampledValue) {
			return [self.underlyingGenerator signalWithValue:RACTuplePack(input, sampledValue)];
		}]
		setNameWithFormat:@"%@ -signalWithValue: %@", self, [input rac_description]];
}

@end
