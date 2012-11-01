//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACStreamExamples.h"

#import "RACSequence.h"

static NSString * const RACSequenceExamples = @"RACSequenceExamples";
static NSString * const RACSequenceSequence = @"RACSequenceSequence";
static NSString * const RACSequenceExpectedValues = @"RACSequenceExpectedValues";

SharedExampleGroupsBegin(RACSequenceExamples);

sharedExamplesFor(RACSequenceExamples, ^(NSDictionary *data) {
	RACSequence *sequence = data[RACSequenceSequence];
	NSArray *values = data[RACSequenceExpectedValues];

	it(@"should implement <NSFastEnumeration>", ^{
		NSMutableArray *collectedValues = [NSMutableArray array];
		for (id value in sequence) {
			[collectedValues addObject:value];
		}

		expect(collectedValues).to.equal(values);
	});

	it(@"should return an array", ^{
		expect(sequence.array).to.equal(values);
	});

	it(@"should be equal to itself", ^{
		expect(sequence).to.equal(sequence);
	});

	it(@"should be equal to the same sequence of values", ^{
		RACSequence *newSequence = nil;
		for (id value in values) {
			RACSequence *valueSeq = [RACSequence return:value];
			expect(valueSeq).notTo.beNil();

			if (newSequence == nil) {
				newSequence = valueSeq;
			} else {
				newSequence = [newSequence concat:valueSeq];
			}
		}
		
		expect(sequence).to.equal(newSequence);
		expect(sequence.hash).to.equal(newSequence.hash);
	});

	it(@"should not be equal to a different sequence of values", ^{
		RACSequence *anotherSequence = [RACSequence return:@(-1)];
		expect(sequence).notTo.equal(anotherSequence);
	});

	it(@"should return an identical object for -copy", ^{
		expect([sequence copy]).to.beIdenticalTo(sequence);
	});

	it(@"should archive", ^{
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sequence];
		expect(data).notTo.beNil();

		RACSequence *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		expect(unarchived).to.equal(sequence);
	});
});

SharedExampleGroupsEnd

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
