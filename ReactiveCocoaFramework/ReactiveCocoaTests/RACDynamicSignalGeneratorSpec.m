//
//  RACDynamicSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-23.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSignalGenerator+Operations.h"

SpecBegin(RACDynamicSignalGenerator)

it(@"should generate signals using a block", ^{
	RACDynamicSignalGenerator *generator = [[RACDynamicSignalGenerator alloc] initWithBlock:^(NSNumber *input) {
		return [RACSignal return:@(input.integerValue * 2)];
	}];

	expect(generator).notTo.beNil();
	expect([[generator signalWithValue:@0] array]).to.equal(@[ @0 ]);
	expect([[generator signalWithValue:@1] array]).to.equal(@[ @2 ]);
	expect([[generator signalWithValue:@2] array]).to.equal(@[ @4 ]);
});

it(@"should generate signals using a reflexive block", ^{
	RACDynamicSignalGenerator *generator = [[RACDynamicSignalGenerator alloc] initWithReflexiveBlock:^(NSNumber *input, RACSignalGenerator *generator) {
		expect(generator).notTo.beNil();

		if (input.integerValue > 5) return [RACSignal empty];

		return [[RACSignal
			return:input]
			concat:[generator signalWithValue:@(input.integerValue + 1)]];
	}];

	expect(generator).notTo.beNil();
	expect([[generator signalWithValue:@3] array]).to.equal((@[ @3, @4, @5 ]));
	expect([[generator signalWithValue:@2] array]).to.equal((@[ @2, @3, @4, @5 ]));
	expect([[generator signalWithValue:@6] array]).to.equal((@[]));
});

it(@"should postcompose with another generator", ^{
	RACDynamicSignalGenerator *squareEvens = [[RACDynamicSignalGenerator alloc] initWithBlock:^(NSNumber *input) {
		if (input.integerValue % 2 == 0) {
			return [RACSignal return:@(input.integerValue * 2)];
		} else {
			return [RACSignal empty];
		}
	}];

	RACDynamicSignalGenerator *plusOne = [[RACDynamicSignalGenerator alloc] initWithBlock:^(NSNumber *input) {
		return [RACSignal return:@(input.integerValue + 1)];
	}];

	RACSignalGenerator *generator = [squareEvens postcompose:plusOne];
	expect(generator).notTo.beNil();

	expect([[generator signalWithValue:@1] array]).to.equal(@[]);
	expect([[generator signalWithValue:@2] array]).to.equal(@[ @5 ]);
	expect([[generator signalWithValue:@4] array]).to.equal(@[ @9 ]);
});

SpecEnd
