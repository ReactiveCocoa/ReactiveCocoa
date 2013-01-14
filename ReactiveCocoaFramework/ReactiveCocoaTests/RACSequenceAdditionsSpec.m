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
	__block NSMutableArray *values;
	__block RACSequence *sequence;
	
	beforeEach(^{
		values = [@[ @0, @1, @2, @3, @4, @5 ] mutableCopy];

		sequence = values.rac_sequence;
		expect(sequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		beforeEach(^{
			unchangedValues = [values copy];
			[values addObject:@6];
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
});

describe(@"NSDictionary sequences", ^{
	__block NSMutableDictionary *dict;

	__block NSMutableArray *tuples;
	__block RACSequence *tupleSequence;

	__block NSArray *keys;
	__block RACSequence *keySequence;

	__block NSArray *values;
	__block RACSequence *valueSequence;

	beforeEach(^{
		dict = [@{
			@"foo": @"bar",
			@"baz": @"buzz",
			@5: NSNull.null
		} mutableCopy];

		tuples = [NSMutableArray array];
		for (id key in dict) {
			RACTuple *tuple = [RACTuple tupleWithObjects:key, dict[key], nil];
			[tuples addObject:tuple];
		}

		tupleSequence = dict.rac_sequence;
		expect(tupleSequence).notTo.beNil();

		keys = [dict.allKeys copy];
		keySequence = dict.rac_keySequence;
		expect(keySequence).notTo.beNil();

		values = [dict.allValues copy];
		valueSequence = dict.rac_valueSequence;
		expect(valueSequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: tupleSequence,
			RACSequenceExampleExpectedValues: tuples
		};
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: keySequence,
			RACSequenceExampleExpectedValues: keys
		};
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: valueSequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	describe(@"should be immutable", ^{
		beforeEach(^{
			dict[@"foo"] = @"rab";
			dict[@6] = @7;
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: tupleSequence,
				RACSequenceExampleExpectedValues: tuples
			};
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: keySequence,
				RACSequenceExampleExpectedValues: keys
			};
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: valueSequence,
				RACSequenceExampleExpectedValues: values
			};
		});
	});
});

describe(@"NSOrderedSet sequences", ^{
	__block NSMutableOrderedSet *values;
	__block RACSequence *sequence;

	beforeEach(^{
		values = [NSMutableOrderedSet orderedSetWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
		sequence = values.rac_sequence;
		expect(sequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values.array
		};
	});

	describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		beforeEach(^{
			unchangedValues = [values.array copy];
			[values addObject:@6];
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
});

describe(@"NSSet sequences", ^{
	__block NSMutableSet *values;
	__block RACSequence *sequence;

	beforeEach(^{
		values = [NSMutableSet setWithArray:@[ @0, @1, @2, @3, @4, @5 ]];
		sequence = values.rac_sequence;
		expect(sequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values.allObjects
		};
	});

	describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		beforeEach(^{
			unchangedValues = [values.allObjects copy];
			[values addObject:@6];
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
});

describe(@"NSString sequences", ^{
	__block NSMutableString *string;
	__block NSArray *values;
	__block RACSequence *sequence;

	beforeEach(^{
		string = [@"foobar" mutableCopy];
		values = @[ @"f", @"o", @"o", @"b", @"a", @"r" ];
		sequence = string.rac_sequence;
		expect(sequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	describe(@"should be immutable", ^{
		beforeEach(^{
			[string appendString:@"buzz"];
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: values
			};
		});
	});
});

SpecEnd
