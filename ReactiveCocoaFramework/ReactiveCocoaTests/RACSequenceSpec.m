//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"

#import "RACSequence.h"

SpecBegin(RACSequence)

it(@"should implement <RACStream>", ^{
	id verifyValues = ^(RACSequence *sequence, NSArray *expectedValues) {
		expect(sequence).notTo.beNil();

		NSMutableArray *collectedValues = [NSMutableArray array];
		while (sequence.head != nil) {
			[collectedValues addObject:sequence.head];
			sequence = sequence.tail;
		}

		expect(collectedValues).to.equal(expectedValues);
	};

	itShouldBehaveLike(RACStreamExamples, @{ RACStreamExamplesClass: RACSequence.class, RACStreamExamplesVerifyValuesBlock: verifyValues });
});

describe(@"+sequenceWithHeadBlock:tailBlock:", ^{
	it(@"should use the values from the head and tail blocks", ^{
		RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^{
			return @0;
		} tailBlock:^{
			return [RACSequence return:@1];
		}];

		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@0);
		expect(sequence.tail.head).to.equal(@1);
		expect(sequence.tail.tail).to.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: @[ @0, @1 ] });
	});

	it(@"should lazily invoke head and tail blocks", ^{
		__block BOOL headInvoked = NO;
		__block BOOL tailInvoked = NO;

		RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^ id {
			headInvoked = YES;
			return nil;
		} tailBlock:^ id {
			tailInvoked = YES;
			return nil;
		}];

		expect(sequence).notTo.beNil();
		expect(headInvoked).to.beFalsy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.head).to.beNil();
		expect(headInvoked).to.beTruthy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.tail).to.beNil();
		expect(tailInvoked).to.beTruthy();
	});
});

it(@"should support empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: RACSequence.empty, RACSequenceExpectedValues: @[] });
});

it(@"should support non-empty sequences", ^{
	RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	NSArray *values = @[ @0, @1, @2 ];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
});

SpecEnd
