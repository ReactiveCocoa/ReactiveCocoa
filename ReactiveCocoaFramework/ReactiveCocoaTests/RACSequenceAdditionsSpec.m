//
//  RACSequenceAdditionsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSequenceExamples.h"

#import "RACSequence.h"
#import "NSArray+RACSequenceAdditions.h"
#import "NSDictionary+RACSequenceAdditions.h"
#import "NSOrderedSet+RACSequenceAdditions.h"
#import "NSSet+RACSequenceAdditions.h"
#import "NSString+RACSequenceAdditions.h"

SpecBegin(RACSequenceAdditions)

describe(@"NSArray sequences", ^{
	__block NSMutableArray *values;
	__block RACSequence *sequence;

	before(^{
		values = [@[ @0, @1, @2, @3, @4, @5 ] mutableCopy];
		sequence = values.rac_sequence;
	});

	it(@"should initialize", ^{
		expect(sequence).notTo.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
	});

	it(@"should not change even if the underlying array does", ^{
		NSArray *unchangedValues = [values copy];
		[values addObject:@6];

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: unchangedValues });
	});
});

describe(@"NSSet sequences", ^{
	__block NSMutableSet *values;
	__block RACSequence *sequence;

	before(^{
		values = [NSMutableSet setWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
		sequence = values.rac_sequence;
	});

	it(@"should initialize", ^{
		expect(sequence).notTo.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values.allObjects });
	});

	it(@"should not change even if the underlying set does", ^{
		NSArray *unchangedValues = [values.allObjects copy];
		[values addObject:@6];

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: unchangedValues });
	});
});

describe(@"NSString sequences", ^{
	__block NSMutableString *string;
	__block NSArray *values;
	__block RACSequence *sequence;

	before(^{
		string = [@"foobar" mutableCopy];
		values = @[ @"f", @"o", @"o", @"b", @"a", @"r" ];
		sequence = string.rac_sequence;
	});

	it(@"should initialize", ^{
		expect(sequence).notTo.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
	});

	it(@"should not change even if the underlying string does", ^{
		[string appendString:@"buzz"];

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values });
	});
});

SpecEnd
