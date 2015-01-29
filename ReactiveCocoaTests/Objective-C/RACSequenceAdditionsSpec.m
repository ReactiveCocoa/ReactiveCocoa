//
//  RACSequenceAdditionsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSequenceExamples.h"

#import "NSArray+RACSequenceAdditions.h"
#import "NSDictionary+RACSequenceAdditions.h"
#import "NSOrderedSet+RACSequenceAdditions.h"
#import "NSSet+RACSequenceAdditions.h"
#import "NSString+RACSequenceAdditions.h"
#import "NSIndexSet+RACSequenceAdditions.h"
#import "RACSequence.h"
#import "RACTuple.h"

QuickSpecBegin(RACSequenceAdditionsSpec)

__block NSArray *numbers;

qck_beforeEach(^{
	NSMutableArray *mutableNumbers = [NSMutableArray array];
	for (NSUInteger i = 0; i < 100; i++) {
		[mutableNumbers addObject:@(i)];
	}

	numbers = [mutableNumbers copy];
});

qck_describe(@"NSArray sequences", ^{
	__block NSMutableArray *values;
	__block RACSequence *sequence;
	
	qck_beforeEach(^{
		values = [numbers mutableCopy];
		sequence = values.rac_sequence;
		expect(sequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	qck_describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		qck_beforeEach(^{
			unchangedValues = [values copy];
			[values addObject:@6];
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});

	qck_it(@"should fast enumerate after zipping", ^{
		// This certain list of values causes issues, for some reason.
		NSArray *values = @[ @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0 ];
		RACSequence *zippedSequence = [RACSequence zip:@[ values.rac_sequence, values.rac_sequence ] reduce:^(id obj1, id obj2) {
			return obj1;
		}];

		NSMutableArray *collectedValues = [NSMutableArray array];
		for (id value in zippedSequence) {
			[collectedValues addObject:value];
		}

		expect(collectedValues).to(equal(values));
	});
});

qck_describe(@"NSDictionary sequences", ^{
	__block NSMutableDictionary *dict;

	__block NSMutableArray *tuples;
	__block RACSequence *tupleSequence;

	__block NSArray *keys;
	__block RACSequence *keySequence;

	__block NSArray *values;
	__block RACSequence *valueSequence;

	qck_beforeEach(^{
		dict = [@{
			@"foo": @"bar",
			@"baz": @"buzz",
			@5: NSNull.null
		} mutableCopy];

		tuples = [NSMutableArray array];
		for (id key in dict) {
			RACTuple *tuple = RACTuplePack(key, dict[key]);
			[tuples addObject:tuple];
		}

		tupleSequence = dict.rac_sequence;
		expect(tupleSequence).notTo(beNil());

		keys = [dict.allKeys copy];
		keySequence = dict.rac_keySequence;
		expect(keySequence).notTo(beNil());

		values = [dict.allValues copy];
		valueSequence = dict.rac_valueSequence;
		expect(valueSequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: tupleSequence,
			RACSequenceExampleExpectedValues: tuples
		};
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: keySequence,
			RACSequenceExampleExpectedValues: keys
		};
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: valueSequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	qck_describe(@"should be immutable", ^{
		qck_beforeEach(^{
			dict[@"foo"] = @"rab";
			dict[@6] = @7;
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: tupleSequence,
				RACSequenceExampleExpectedValues: tuples
			};
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: keySequence,
				RACSequenceExampleExpectedValues: keys
			};
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: valueSequence,
				RACSequenceExampleExpectedValues: values
			};
		});
	});
});

qck_describe(@"NSOrderedSet sequences", ^{
	__block NSMutableOrderedSet *values;
	__block RACSequence *sequence;

	qck_beforeEach(^{
		values = [NSMutableOrderedSet orderedSetWithArray:numbers];
		sequence = values.rac_sequence;
		expect(sequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values.array
		};
	});

	qck_describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		qck_beforeEach(^{
			unchangedValues = [values.array copy];
			[values addObject:@6];
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
});

qck_describe(@"NSSet sequences", ^{
	__block NSMutableSet *values;
	__block RACSequence *sequence;

	qck_beforeEach(^{
		values = [NSMutableSet setWithArray:numbers];
		sequence = values.rac_sequence;
		expect(sequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values.allObjects
		};
	});

	qck_describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		qck_beforeEach(^{
			unchangedValues = [values.allObjects copy];
			[values addObject:@6];
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
});

qck_describe(@"NSString sequences", ^{
	__block NSMutableString *string;
	__block NSArray *values;
	__block RACSequence *sequence;

	qck_beforeEach(^{
		string = [@"foobar" mutableCopy];
		values = @[ @"f", @"o", @"o", @"b", @"a", @"r" ];
		sequence = string.rac_sequence;
		expect(sequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: values
		};
	});

	qck_describe(@"should be immutable", ^{
		qck_beforeEach(^{
			[string appendString:@"buzz"];
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: values
			};
		});
	});

	qck_it(@"should work with composed characters", ^{
		NSString  *string = @"\u2665\uFE0F\u2666\uFE0F";
		NSArray *expectedSequence = @[ @"\u2665\uFE0F", @"\u2666\uFE0F" ];
		expect(string.rac_sequence.array).to(equal(expectedSequence));
	});
});

qck_describe(@"RACTuple sequences", ^{
	__block RACTuple *tuple;
	__block RACSequence *sequence;
	
	qck_beforeEach(^{
		tuple = RACTuplePack(@"foo", nil, @"bar", NSNull.null, RACTupleNil.tupleNil);

		sequence = tuple.rac_sequence;
		expect(sequence).notTo(beNil());
	});

	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: @[ @"foo", NSNull.null, @"bar", NSNull.null, NSNull.null ]
		};
	});
});

qck_describe(@"NSIndexSet sequences", ^{
	__block NSMutableIndexSet *values;
	__block RACSequence *sequence;
	
	NSArray * (^valuesFromIndexSet)(NSIndexSet *indexSet) =  ^NSArray *(NSIndexSet *indexSet) {
		NSMutableArray *arr = [NSMutableArray array];
		[indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			[arr addObject:@(idx)];
		}];

		return [arr copy];
	};
	
	qck_beforeEach(^{
		values = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 10)];
		sequence = values.rac_sequence;
		expect(sequence).notTo(beNil());
	});
	
	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: sequence,
			RACSequenceExampleExpectedValues: valuesFromIndexSet(values)
		};
	});
	
	qck_describe(@"should be immutable", ^{
		__block NSArray *unchangedValues;
		
		qck_beforeEach(^{
			unchangedValues = valuesFromIndexSet(values);
			[values addIndex:20];
		});
		
		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: unchangedValues
			};
		});
	});
	
	qck_describe(@"should not fire if empty", ^{
		__block NSIndexSet *emptyIndexSet;
		__block RACSequence *emptySequence;

		qck_beforeEach(^{
			emptyIndexSet = [NSIndexSet indexSet];
			emptySequence = emptyIndexSet.rac_sequence;
			expect(emptySequence).notTo(beNil());
		});

		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: emptySequence,
				RACSequenceExampleExpectedValues: valuesFromIndexSet(emptyIndexSet)
			};
		});
	});
});

QuickSpecEnd
