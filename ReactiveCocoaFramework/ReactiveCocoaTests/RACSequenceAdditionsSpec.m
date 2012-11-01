//
//  RACSequenceAdditionsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSequenceExamples.h"

#import "NSArray+RACSequenceAdditions.h"
#import "NSDictionary+RACSequenceAdditions.h"
#import "NSOrderedSet+RACSequenceAdditions.h"
#import "NSSet+RACSequenceAdditions.h"
#import "NSString+RACSequenceAdditions.h"
#import "RACSequence.h"
#import "RACTuple.h"

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

describe(@"NSDictionary sequences", ^{
	__block NSMutableDictionary *dict;

	__block RACSequence *tupleSequence;
	__block NSMutableArray *tuples;

	__block RACSequence *keySequence;
	__block NSArray *keys;

	__block RACSequence *valueSequence;
	__block NSArray *values;

	before(^{
		dict = [@{
			@"foo": @"bar",
			@"baz": @"buzz",
			@5: NSNull.null
		} mutableCopy];

		tupleSequence = dict.rac_sequence;
		tuples = [NSMutableArray array];
		for (id key in dict) {
			RACTuple *tuple = [RACTuple tupleWithObjects:key, dict[key], nil];
			[tuples addObject:tuple];
		}

		keySequence = dict.rac_keySequence;
		keys = [dict.allKeys copy];

		valueSequence = dict.rac_valueSequence;
		values = [dict.allValues copy];
	});

	it(@"should initialize", ^{
		expect(tupleSequence).notTo.beNil();
		expect(keySequence).notTo.beNil();
		expect(valueSequence).notTo.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: tupleSequence, RACSequenceExpectedValues: tuples });
		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: keySequence, RACSequenceExpectedValues: keys });
		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: valueSequence, RACSequenceExpectedValues: values });
	});

	it(@"should not change even if the underlying dictionary does", ^{
		dict[@"foo"] = @"rab";
		dict[@6] = @7;

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: tupleSequence, RACSequenceExpectedValues: tuples });
		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: keySequence, RACSequenceExpectedValues: keys });
		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: valueSequence, RACSequenceExpectedValues: values });
	});
});

describe(@"NSOrderedSet sequences", ^{
	__block NSMutableOrderedSet *values;
	__block RACSequence *sequence;

	before(^{
		values = [NSMutableOrderedSet orderedSetWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
		sequence = values.rac_sequence;
	});

	it(@"should initialize", ^{
		expect(sequence).notTo.beNil();

		itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values.array });
	});

	it(@"should not change even if the underlying ordered set does", ^{
		NSArray *unchangedValues = [values.array copy];
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
