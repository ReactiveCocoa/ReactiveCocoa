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
#import "NSIndexSet+RACSequenceAdditions.h"
#import "RACSequence.h"
#import "RACTuple.h"

SpecBegin(RACSequenceAdditions)

__block NSArray *numbers;

beforeEach(^{
	NSMutableArray *mutableNumbers = [NSMutableArray array];
	for (NSUInteger i = 0; i < 100; i++) {
		[mutableNumbers addObject:@(i)];
	}

	numbers = [mutableNumbers copy];
});

describe(@"NSArray sequences", ^{
	__block NSMutableArray *values;
	__block RACSequence *sequence;
	
	beforeEach(^{
		values = [numbers mutableCopy];
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

	it(@"should fast enumerate after zipping", ^{
		// This certain list of values causes issues, for some reason.
		NSArray *values = @[ @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0 ];
		RACSequence *zippedSequence = [RACSequence zip:@[ values.rac_sequence, values.rac_sequence ] reduce:^(id obj1, id obj2) {
			return obj1;
		}];

		NSMutableArray *collectedValues = [NSMutableArray array];
		for (id value in zippedSequence) {
			[collectedValues addObject:value];
		}

		expect(collectedValues).to.equal(values);
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
		values = [NSMutableOrderedSet orderedSetWithArray:numbers];
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
		values = [NSMutableSet setWithArray:numbers];
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

	it(@"should work with composed characters", ^{
		NSString  *string = @"\u2665\uFE0F\u2666\uFE0F";
		NSArray *expectedSequence = @[ @"\u2665\uFE0F", @"\u2666\uFE0F" ];
		expect(string.rac_sequence.array).to.equal(expectedSequence);
	});
});

describe(@"RACTuple sequences", ^{
	__block RACTuple *tuple;
	__block RACSequence *sequence;
	
	beforeEach(^{
		tuple = RACTuplePack(@"foo", nil, @"bar", NSNull.null, RACTupleNil.tupleNil);

		sequence = tuple.rac_sequence;
		expect(sequence).notTo.beNil();
	});

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: @[ @"foo", NSNull.null, @"bar", NSNull.null, NSNull.null ]
		};
	});
});

describe(@"NSIndexSet sequences", ^{
	__block NSMutableIndexSet *values;
	__block RACSequence *sequence;
	
	NSArray * (^valuesFromIndexSet)(NSIndexSet *indexSet) =  ^NSArray *(NSIndexSet *indexSet) {
		NSMutableArray *arr = [NSMutableArray array];
		[indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[arr addObject:@(idx)];
		}];

		return [arr copy];
	};
	
	beforeEach(^{
		values = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 10)];
		sequence = values.rac_sequence;
		expect(sequence).notTo.beNil();
	});
	
	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: valuesFromIndexSet(values)
		};
	});
	
	describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		beforeEach(^{
			unchangedValues = valuesFromIndexSet(values);
			[values addIndex:20];
		});
		
		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
	
	describe(@"should not fire if empty", ^{
		__block NSIndexSet *emptyIndexSet;
		__block RACSequence *emptySequence;

		beforeEach(^{
			emptyIndexSet = [NSIndexSet indexSet];
			emptySequence = emptyIndexSet.rac_sequence;
			expect(emptySequence).notTo.beNil();
		});

		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: emptySequence,
				RACSequenceExampleExpectedValues: valuesFromIndexSet(emptyIndexSet)
			};
		});
	});
});

SpecEnd
