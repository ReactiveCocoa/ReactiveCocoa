//
//  RACCollectionSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "NSDictionary+RACSupport.h"
#import "NSOrderedSet+RACSupport.h"
#import "NSSet+RACSupport.h"
#import "NSString+RACSupport.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

SpecBegin(RACCollectionSupport)

__block NSArray *numbers;

beforeEach(^{
	NSMutableArray *mutableNumbers = [NSMutableArray array];
	for (NSUInteger i = 0; i < 100; i++) {
		[mutableNumbers addObject:@(i)];
	}

	numbers = [mutableNumbers copy];
});

describe(@"NSArray signals", ^{
	__block NSMutableArray *values;
	__block RACSignal *signal;
	
	beforeEach(^{
		values = [numbers mutableCopy];
		signal = values.rac_signal;
		expect(signal).notTo.beNil();
	});

	it(@"should be immutable", ^{
		NSArray *unchangedValues = [values copy];
		expect([signal array]).to.equal(unchangedValues);

		[values addObject:@6];
		expect([signal array]).to.equal(unchangedValues);
	});
});

describe(@"NSDictionary signals", ^{
	__block NSMutableDictionary *dict;

	__block NSMutableArray *tuples;
	__block RACSignal *tupleSignal;

	__block NSArray *keys;
	__block RACSignal *keySignal;

	__block NSArray *values;
	__block RACSignal *valueSignal;

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

		tupleSignal = dict.rac_signal;
		expect(tupleSignal).notTo.beNil();

		keys = [dict.allKeys copy];
		keySignal = dict.rac_keySignal;
		expect(keySignal).notTo.beNil();

		values = [dict.allValues copy];
		valueSignal = dict.rac_valueSignal;
		expect(valueSignal).notTo.beNil();
	});

	it(@"should be immutable", ^{
		expect([tupleSignal array]).to.equal(tuples);
		expect([keySignal array]).to.equal(keys);
		expect([valueSignal array]).to.equal(values);

		dict[@"foo"] = @"rab";
		dict[@6] = @7;

		expect([tupleSignal array]).to.equal(tuples);
		expect([keySignal array]).to.equal(keys);
		expect([valueSignal array]).to.equal(values);
	});
});

describe(@"NSOrderedSet signals", ^{
	__block NSMutableOrderedSet *values;
	__block RACSignal *signal;

	beforeEach(^{
		values = [NSMutableOrderedSet orderedSetWithArray:numbers];
		signal = values.rac_signal;
		expect(signal).notTo.beNil();
	});

	it(@"should be immutable", ^{
		NSArray *unchangedValues = [values.array copy];
		expect([signal array]).to.equal(unchangedValues);

		[values addObject:@6];
		expect([signal array]).to.equal(unchangedValues);
	});
});

describe(@"NSSet signals", ^{
	__block NSMutableSet *values;
	__block RACSignal *signal;

	beforeEach(^{
		values = [NSMutableSet setWithArray:numbers];
		signal = values.rac_signal;
		expect(signal).notTo.beNil();
	});

	it(@"should be immutable", ^{
		NSArray *unchangedValues = [values.allObjects copy];
		expect([signal array]).to.equal(unchangedValues);

		[values addObject:@6];
		expect([signal array]).to.equal(unchangedValues);
	});
});

describe(@"NSString signals", ^{
	__block NSMutableString *string;
	__block NSArray *values;
	__block RACSignal *signal;

	beforeEach(^{
		string = [@"foobar" mutableCopy];
		values = @[ @"f", @"o", @"o", @"b", @"a", @"r" ];
		signal = string.rac_signal;
		expect(signal).notTo.beNil();
	});

	it(@"should be immutable", ^{
		expect([signal array]).to.equal(values);

		[string appendString:@"buzz"];
		expect([signal array]).to.equal(values);
	});

	it(@"should work with composed characters", ^{
		NSString *string = @"\u2665\uFE0F\u2666\uFE0F";
		NSArray *expectedSignal = @[ @"\u2665\uFE0F", @"\u2666\uFE0F" ];
		expect([string.rac_signal array]).to.equal(expectedSignal);
	});
});

describe(@"RACTuple signals", ^{
	__block RACTuple *tuple;
	__block RACSignal *signal;
	
	beforeEach(^{
		tuple = RACTuplePack(@"foo", nil, @"bar", NSNull.null, RACTupleNil.tupleNil);

		signal = tuple.rac_signal;
		expect(signal).notTo.beNil();
	});

	it(@"should match tuple", ^{
		NSArray *values = @[
			@"foo",
			NSNull.null,
			@"bar",
			NSNull.null,
			NSNull.null,
		];

		expect([signal array]).to.equal(values);
	});
});

SpecEnd
