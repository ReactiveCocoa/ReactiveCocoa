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

it(@"empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: RACSequence.empty, RACSequenceExpectedValues: @[] });
});

it(@"non-empty sequences", ^{
	RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	NSArray *values = @[ @0, @1, @2 ];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
});

SpecEnd
