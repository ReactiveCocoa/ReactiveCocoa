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

describe(@"<RACStream>", ^{
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
	__block RACSequence *sequence;
	__block BOOL headInvoked;
	__block BOOL tailInvoked;

	before(^{
		headInvoked = NO;
		tailInvoked = NO;

		sequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];

		expect(sequence).notTo.beNil();
	});

	it(@"should use the values from the head and tail blocks", ^{
		expect(sequence.head).to.equal(@0);
		expect(sequence.tail.head).to.equal(@1);
		expect(sequence.tail.tail).to.beNil();
	});

	it(@"should lazily invoke head and tail blocks", ^{
		expect(headInvoked).to.beFalsy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.head).to.equal(@0);
		expect(headInvoked).to.beTruthy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.tail).notTo.beNil();
		expect(tailInvoked).to.beTruthy();
	});

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: @[ @0, @1 ] });
});

describe(@"empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: RACSequence.empty, RACSequenceExpectedValues: @[] });
});

describe(@"non-empty sequences", ^{
	RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	NSArray *values = @[ @0, @1, @2 ];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
});

SpecEnd
