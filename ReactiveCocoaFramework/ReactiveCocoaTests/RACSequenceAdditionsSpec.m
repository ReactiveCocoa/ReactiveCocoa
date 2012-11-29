//
//  RACSequenceAdditionsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

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
	NSMutableArray *values = [@[ @0, @1, @2, @3, @4, @5 ] mutableCopy];
	RACSequence *sequence = values.rac_sequence;
	expect(sequence).notTo.beNil();

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values }, nil);

	NSArray *unchangedValues = [values copy];
	[values addObject:@6];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: unchangedValues }, nil);
});

describe(@"NSDictionary sequences", ^{
	NSMutableDictionary *dict = [@{
		@"foo": @"bar",
		@"baz": @"buzz",
		@5: NSNull.null
	} mutableCopy];

	NSMutableArray *tuples = [NSMutableArray array];
	for (id key in dict) {
		RACTuple *tuple = [RACTuple tupleWithObjects:key, dict[key], nil];
		[tuples addObject:tuple];
	}

	RACSequence *tupleSequence = dict.rac_sequence;
	expect(tupleSequence).notTo.beNil();

	NSArray *keys = [dict.allKeys copy];
	RACSequence *keySequence = dict.rac_keySequence;
	expect(keySequence).notTo.beNil();

	NSArray *values = [dict.allValues copy];
	RACSequence *valueSequence = dict.rac_valueSequence;
	expect(valueSequence).notTo.beNil();

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: tupleSequence, RACSequenceExpectedValues: tuples }, nil);
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: keySequence, RACSequenceExpectedValues: keys }, nil);
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: valueSequence, RACSequenceExpectedValues: values }, nil);

	dict[@"foo"] = @"rab";
	dict[@6] = @7;

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: tupleSequence, RACSequenceExpectedValues: tuples }, nil);
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: keySequence, RACSequenceExpectedValues: keys }, nil);
	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: valueSequence, RACSequenceExpectedValues: values }, nil);
});

describe(@"NSOrderedSet sequences", ^{
	NSMutableOrderedSet *values = [NSMutableOrderedSet orderedSetWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
	RACSequence *sequence = values.rac_sequence;
	expect(sequence).notTo.beNil();

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values.array }, nil);

	NSArray *unchangedValues = [values.array copy];
	[values addObject:@6];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: unchangedValues }, nil);
});

describe(@"NSSet sequences", ^{
	NSMutableSet *values = [NSMutableSet setWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
	RACSequence *sequence = values.rac_sequence;
	expect(sequence).notTo.beNil();

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values.allObjects }, nil);

	NSArray *unchangedValues = [values.allObjects copy];
	[values addObject:@6];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: unchangedValues }, nil);
});

describe(@"NSString sequences", ^{
	NSMutableString *string = [@"foobar" mutableCopy];
	NSArray *values = @[ @"f", @"o", @"o", @"b", @"a", @"r" ];
	RACSequence *sequence = string.rac_sequence;
	expect(sequence).notTo.beNil();

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values }, nil);

	[string appendString:@"buzz"];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: sequence, RACSequenceExpectedValues: values }, nil);
});

SpecEnd
