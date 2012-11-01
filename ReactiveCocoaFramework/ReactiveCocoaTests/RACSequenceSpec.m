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

SpecEnd
