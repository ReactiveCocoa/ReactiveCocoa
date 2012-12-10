//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"

#import "RACSequence.h"
#import "RACUnit.h"

SpecBegin(RACSequence)

describe(@"<RACStream>", ^{
	id verifyValues = ^(RACSequence *sequence, NSArray *expectedValues) {
		NSMutableArray *collectedValues = [NSMutableArray array];
		while (sequence.head != nil) {
			[collectedValues addObject:sequence.head];
			sequence = sequence.tail;
		}

		expect(collectedValues).to.equal(expectedValues);
	};

	__block RACSequence *infiniteSequence = [RACSequence sequenceWithHeadBlock:^{
		return RACUnit.defaultUnit;
	} tailBlock:^{
		return infiniteSequence;
	}];

	itShouldBehaveLike(RACStreamExamples, @{
		RACStreamExamplesClass: RACSequence.class,
		RACStreamExamplesVerifyValuesBlock: verifyValues,
		RACStreamExamplesInfiniteStream: infiniteSequence
	}, nil);
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

	after(^{
		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: @[ @0, @1 ] }, nil);
	});
});

describe(@"empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: RACSequence.empty, RACSequenceExpectedValues: @[] }, nil);
});

describe(@"non-empty sequences", ^{
	RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	NSArray *values = @[ @0, @1, @2 ];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values }, nil);
});

describe(@"-take:", ^{
	it(@"should complete take: without needing the head of the second item in the sequence", ^{
		__block NSUInteger valuesTaken = 0;

		__block RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^{
			++valuesTaken;
			return RACUnit.defaultUnit;
		} tailBlock:^{
			return sequence;
		}];

		NSArray *values = [sequence take:1].array;
		expect(values).to.equal(@[ RACUnit.defaultUnit ]);
		expect(valuesTaken).to.equal(1);
	});
});

describe(@"-bind:", ^{
	it(@"should only evaluate head when the resulting sequence is evaluated", ^{
		__block BOOL headInvoked = NO;

		RACSequence *original = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return RACUnit.defaultUnit;
		} tailBlock:^ id {
			return nil;
		}];

		RACSequence *bound = [original bind:^{
			return ^(id value, BOOL *stop) {
				return [RACSequence return:value];
			};
		}];

		expect(bound).notTo.beNil();
		expect(headInvoked).to.beFalsy();

		expect(bound.head).to.equal(RACUnit.defaultUnit);
		expect(headInvoked).to.beTruthy();
	});
});

SpecEnd
