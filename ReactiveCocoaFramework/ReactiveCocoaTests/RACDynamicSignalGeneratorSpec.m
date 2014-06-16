//
//  RACDynamicSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-23.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDynamicSignalGenerator.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACSignal+Operations.h"

SpecBegin(RACDynamicSignalGenerator)

it(@"should generate signals using a block", ^{
	RACDynamicSignalGenerator *generator = [RACDynamicSignalGenerator generatorWithBlock:^(NSNumber *input) {
		return [RACSignal return:@(input.integerValue * 2)];
	}];

	expect(generator).notTo.beNil();
	expect([[generator signalWithValue:@0] array]).to.equal(@[ @0 ]);
	expect([[generator signalWithValue:@1] array]).to.equal(@[ @2 ]);
	expect([[generator signalWithValue:@2] array]).to.equal(@[ @4 ]);
});

it(@"should generate a constant signal", ^{
	RACSignalGenerator *generator = [[RACSignal
		return:nil]
		signalGenerator];

	expect(generator).notTo.beNil();
	expect([[generator signalWithValue:@0] array]).to.equal(@[ NSNull.null ]);
	expect([[generator signalWithValue:@1] array]).to.equal(@[ NSNull.null ]);
	expect([[generator signalWithValue:@2] array]).to.equal(@[ NSNull.null ]);
});

describe(@"with a reflexive block", ^{
	it(@"should generate signals", ^{
		RACDynamicSignalGenerator *generator = [RACDynamicSignalGenerator generatorWithReflexiveBlock:^(NSNumber *input, RACSignalGenerator *generator) {
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

	it(@"should be released when all constructed signals are destroyed", ^{
		__block BOOL generatorDeallocated = NO;
		__block BOOL signalDeallocated = NO;

		@autoreleasepool {
			RACSignalGenerator *generator __attribute__((objc_precise_lifetime)) = [RACDynamicSignalGenerator generatorWithReflexiveBlock:^(NSNumber *input, RACSignalGenerator *generator) {
				if (input.integerValue == 0) return [RACSignal empty];

				return [RACSignal defer:^{
					return [generator signalWithValue:@(input.integerValue - 1)];
				}];
			}];

			[generator.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				generatorDeallocated = YES;
			}]];

			RACSignal *signal = [generator signalWithValue:@1];
			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocated = YES;
			}]];

			BOOL success = [signal waitUntilCompleted:NULL];
			expect(success).to.beTruthy();

			expect(signalDeallocated).to.beFalsy();
			expect(generatorDeallocated).to.beFalsy();
		}

		expect(signalDeallocated).will.beTruthy();
		expect(generatorDeallocated).to.beTruthy();
	});
});

it(@"should postcompose with another generator", ^{
	RACDynamicSignalGenerator *squareEvens = [RACDynamicSignalGenerator generatorWithBlock:^(NSNumber *input) {
		if (input.integerValue % 2 == 0) {
			return [RACSignal return:@(input.integerValue * 2)];
		} else {
			return [RACSignal empty];
		}
	}];

	RACDynamicSignalGenerator *plusOne = [RACDynamicSignalGenerator generatorWithBlock:^(NSNumber *input) {
		return [RACSignal return:@(input.integerValue + 1)];
	}];

	RACSignalGenerator *generator = [squareEvens postcompose:plusOne];
	expect(generator).notTo.beNil();

	expect([[generator signalWithValue:@1] array]).to.equal(@[]);
	expect([[generator signalWithValue:@2] array]).to.equal(@[ @5 ]);
	expect([[generator signalWithValue:@4] array]).to.equal(@[ @9 ]);
});

SpecEnd
