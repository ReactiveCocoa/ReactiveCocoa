//
//  RACStreamExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACStreamExamples.h"

#import "RACStream.h"
#import "RACUnit.h"
#import "RACTuple.h"

NSString * const RACStreamExamples = @"RACStreamExamples";
NSString * const RACStreamExamplesClass = @"RACStreamExamplesClass";
NSString * const RACStreamExamplesInfiniteStream = @"RACStreamExamplesInfiniteStream";
NSString * const RACStreamExamplesVerifyValuesBlock = @"RACStreamExamplesVerifyValuesBlock";

QuickConfigurationBegin(RACStreamExampleGroups)

+ (void)configure:(Configuration *)configuration {
	sharedExamples(RACStreamExamples, ^(QCKDSLSharedExampleContext exampleContext) {
		__block Class streamClass;
		__block void (^verifyValues)(RACStream *, NSArray *);
		__block RACStream *infiniteStream;

		__block RACStream *(^streamWithValues)(NSArray *);

		qck_beforeEach(^{
			streamClass = exampleContext()[RACStreamExamplesClass];
			verifyValues = exampleContext()[RACStreamExamplesVerifyValuesBlock];
			infiniteStream = exampleContext()[RACStreamExamplesInfiniteStream];
			streamWithValues = [^(NSArray *values) {
				RACStream *stream = [streamClass empty];

				for (id value in values) {
					stream = [stream concat:[streamClass return:value]];
				}

				return stream;
			} copy];
		});

		qck_it(@"should return an empty stream", ^{
			RACStream *stream = [streamClass empty];
			verifyValues(stream, @[]);
		});

		qck_it(@"should lift a value into a stream", ^{
			RACStream *stream = [streamClass return:RACUnit.defaultUnit];
			verifyValues(stream, @[ RACUnit.defaultUnit ]);
		});

		qck_describe(@"-concat:", ^{
			qck_it(@"should concatenate two streams", ^{
				RACStream *stream = [[streamClass return:@0] concat:[streamClass return:@1]];
				verifyValues(stream, @[ @0, @1 ]);
			});

			qck_it(@"should concatenate three streams", ^{
				RACStream *stream = [[[streamClass return:@0] concat:[streamClass return:@1]] concat:[streamClass return:@2]];
				verifyValues(stream, @[ @0, @1, @2 ]);
			});

			qck_it(@"should concatenate around an empty stream", ^{
				RACStream *stream = [[[streamClass return:@0] concat:[streamClass empty]] concat:[streamClass return:@2]];
				verifyValues(stream, @[ @0, @2 ]);
			});
		});

		qck_it(@"should flatten", ^{
			RACStream *stream = [[streamClass return:[streamClass return:RACUnit.defaultUnit]] flatten];
			verifyValues(stream, @[ RACUnit.defaultUnit ]);
		});

		qck_describe(@"-bind:", ^{
			qck_it(@"should return the result of binding a single value", ^{
				RACStream *stream = [[streamClass return:@0] bind:^{
					return ^(NSNumber *value, BOOL *stop) {
						NSNumber *newValue = @(value.integerValue + 1);
						return [streamClass return:newValue];
					};
				}];

				verifyValues(stream, @[ @1 ]);
			});

			qck_it(@"should concatenate the result of binding multiple values", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1 ]);
				RACStream *stream = [baseStream bind:^{
					return ^(NSNumber *value, BOOL *stop) {
						NSNumber *newValue = @(value.integerValue + 1);
						return [streamClass return:newValue];
					};
				}];

				verifyValues(stream, @[ @1, @2 ]);
			});

			qck_it(@"should concatenate with an empty result from binding a value", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
				RACStream *stream = [baseStream bind:^{
					return ^(NSNumber *value, BOOL *stop) {
						if (value.integerValue == 1) return [streamClass empty];

						NSNumber *newValue = @(value.integerValue + 1);
						return [streamClass return:newValue];
					};
				}];

				verifyValues(stream, @[ @1, @3 ]);
			});

			qck_it(@"should terminate immediately when returning nil", ^{
				RACStream *stream = [infiniteStream bind:^{
					return ^ id (id _, BOOL *stop) {
						return nil;
					};
				}];

				verifyValues(stream, @[]);
			});

			qck_it(@"should terminate after one value when setting 'stop'", ^{
				RACStream *stream = [infiniteStream bind:^{
					return ^ id (id value, BOOL *stop) {
						*stop = YES;
						return [streamClass return:value];
					};
				}];

				verifyValues(stream, @[ RACUnit.defaultUnit ]);
			});

			qck_it(@"should terminate immediately when returning nil and setting 'stop'", ^{
				RACStream *stream = [infiniteStream bind:^{
					return ^ id (id _, BOOL *stop) {
						*stop = YES;
						return nil;
					};
				}];

				verifyValues(stream, @[]);
			});

			qck_it(@"should be restartable even with block state", ^{
				NSArray *values = @[ @0, @1, @2 ];
				RACStream *baseStream = streamWithValues(values);

				RACStream *countingStream = [baseStream bind:^{
					__block NSUInteger counter = 0;

					return ^(id x, BOOL *stop) {
						return [streamClass return:@(counter++)];
					};
				}];

				verifyValues(countingStream, @[ @0, @1, @2 ]);
				verifyValues(countingStream, @[ @0, @1, @2 ]);
			});

			qck_it(@"should be interleavable even with block state", ^{
				NSArray *values = @[ @0, @1, @2 ];
				RACStream *baseStream = streamWithValues(values);

				RACStream *countingStream = [baseStream bind:^{
					__block NSUInteger counter = 0;

					return ^(id x, BOOL *stop) {
						return [streamClass return:@(counter++)];
					};
				}];

				// Just so +zip:reduce: thinks this is a unique stream.
				RACStream *anotherStream = [[streamClass empty] concat:countingStream];

				RACStream *zipped = [streamClass zip:@[ countingStream, anotherStream ] reduce:^(NSNumber *v1, NSNumber *v2) {
					return @(v1.integerValue + v2.integerValue);
				}];

				verifyValues(zipped, @[ @0, @2, @4 ]);
			});
		});

		qck_describe(@"-flattenMap:", ^{
			qck_it(@"should return a single mapped result", ^{
				RACStream *stream = [[streamClass return:@0] flattenMap:^(NSNumber *value) {
					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				}];

				verifyValues(stream, @[ @1 ]);
			});

			qck_it(@"should concatenate the results of mapping multiple values", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1 ]);
				RACStream *stream = [baseStream flattenMap:^(NSNumber *value) {
					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				}];

				verifyValues(stream, @[ @1, @2 ]);
			});

			qck_it(@"should concatenate with an empty result from mapping a value", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
				RACStream *stream = [baseStream flattenMap:^(NSNumber *value) {
					if (value.integerValue == 1) return [streamClass empty];

					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				}];

				verifyValues(stream, @[ @1, @3 ]);
			});

			qck_it(@"should treat nil streams like empty streams", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
				RACStream *stream = [baseStream flattenMap:^ RACStream * (NSNumber *value) {
					if (value.integerValue == 1) return nil;

					NSNumber *newValue = @(value.integerValue + 1);
					return [streamClass return:newValue];
				}];

				verifyValues(stream, @[ @1, @3 ]);
			});
		});

		qck_it(@"should map", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
			RACStream *stream = [baseStream map:^(NSNumber *value) {
				return @(value.integerValue + 1);
			}];

			verifyValues(stream, @[ @1, @2, @3 ]);
		});

		qck_it(@"should map and replace", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1, @2 ]);
			RACStream *stream = [baseStream mapReplace:RACUnit.defaultUnit];

			verifyValues(stream, @[ RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit ]);
		});

		qck_it(@"should filter", ^{
			RACStream *baseStream = streamWithValues(@[ @0, @1, @2, @3, @4, @5, @6 ]);
			RACStream *stream = [baseStream filter:^ BOOL (NSNumber *value) {
				return value.integerValue % 2 == 0;
			}];

			verifyValues(stream, @[ @0, @2, @4, @6 ]);
		});

		qck_describe(@"-ignore:", ^{
			qck_it(@"should ignore a value", ^{
				RACStream *baseStream = streamWithValues(@[ @0, @1, @2, @3, @4, @5, @6 ]);
				RACStream *stream = [baseStream ignore:@1];

				verifyValues(stream, @[ @0, @2, @3, @4, @5, @6 ]);
			});

			qck_it(@"should ignore based on object equality", ^{
				RACStream *baseStream = streamWithValues(@[ @"0", @"1", @"2", @"3", @"4", @"5", @"6" ]);

				NSMutableString *valueToIgnore = [[NSMutableString alloc] init];
				[valueToIgnore appendString:@"1"];
				RACStream *stream = [baseStream ignore:valueToIgnore];

				verifyValues(stream, @[ @"0", @"2", @"3", @"4", @"5", @"6" ]);
			});
		});

		qck_it(@"should start with a value", ^{
			RACStream *stream = [[streamClass return:@1] startWith:@0];
			verifyValues(stream, @[ @0, @1 ]);
		});

		qck_describe(@"-skip:", ^{
			__block NSArray *values;
			__block RACStream *stream;

			qck_beforeEach(^{
				values = @[ @0, @1, @2 ];
				stream = streamWithValues(values);
			});

			qck_it(@"should skip any valid number of values", ^{
				for (NSUInteger i = 0; i < values.count; i++) {
					verifyValues([stream skip:i], [values subarrayWithRange:NSMakeRange(i, values.count - i)]);
				}
			});

			qck_it(@"should return an empty stream when skipping too many values", ^{
				verifyValues([stream skip:4], @[]);
			});
		});

		qck_describe(@"-take:", ^{
			qck_describe(@"with three values", ^{
				__block NSArray *values;
				__block RACStream *stream;

				qck_beforeEach(^{
					values = @[ @0, @1, @2 ];
					stream = streamWithValues(values);
				});

				qck_it(@"should take any valid number of values", ^{
					for (NSUInteger i = 0; i < values.count; i++) {
						verifyValues([stream take:i], [values subarrayWithRange:NSMakeRange(0, i)]);
					}
				});

				qck_it(@"should return the same stream when taking too many values", ^{
					verifyValues([stream take:4], values);
				});
			});

			qck_it(@"should take and terminate from an infinite stream", ^{
				verifyValues([infiniteStream take:0], @[]);
				verifyValues([infiniteStream take:1], @[ RACUnit.defaultUnit ]);
				verifyValues([infiniteStream take:2], @[ RACUnit.defaultUnit, RACUnit.defaultUnit ]);
			});

			qck_it(@"should take and terminate from a single-item stream", ^{
				NSArray *values = @[ RACUnit.defaultUnit ];
				RACStream *stream = streamWithValues(values);
				verifyValues([stream take:1], values);
			});
		});

		qck_describe(@"zip stream creation methods", ^{
			__block NSArray *valuesOne;

			__block RACStream *streamOne;
			__block RACStream *streamTwo;
			__block RACStream *streamThree;
			__block NSArray *threeStreams;

			__block NSArray *oneStreamTuples;
			__block NSArray *twoStreamTuples;
			__block NSArray *threeStreamTuples;

			qck_beforeEach(^{
				valuesOne = @[ @"Ada", @"Bob", @"Dea" ];
				NSArray *valuesTwo = @[ @"eats", @"cooks", @"jumps" ];
				NSArray *valuesThree = @[ @"fish", @"bear", @"rock" ];

				streamOne = streamWithValues(valuesOne);
				streamTwo = streamWithValues(valuesTwo);
				streamThree = streamWithValues(valuesThree);
				threeStreams = @[ streamOne, streamTwo, streamThree ];

				oneStreamTuples = @[
					RACTuplePack(valuesOne[0]),
					RACTuplePack(valuesOne[1]),
					RACTuplePack(valuesOne[2]),
				];

				twoStreamTuples = @[
					RACTuplePack(valuesOne[0], valuesTwo[0]),
					RACTuplePack(valuesOne[1], valuesTwo[1]),
					RACTuplePack(valuesOne[2], valuesTwo[2]),
				];

				threeStreamTuples = @[
					RACTuplePack(valuesOne[0], valuesTwo[0], valuesThree[0]),
					RACTuplePack(valuesOne[1], valuesTwo[1], valuesThree[1]),
					RACTuplePack(valuesOne[2], valuesTwo[2], valuesThree[2]),
				];
			});

			qck_describe(@"-zipWith:", ^{
				qck_it(@"should make a stream of tuples", ^{
					RACStream *stream = [streamOne zipWith:streamTwo];
					verifyValues(stream, twoStreamTuples);
				});

				qck_it(@"should truncate streams", ^{
					RACStream *shortStream = streamWithValues(@[ @"now", @"later" ]);
					RACStream *stream = [streamOne zipWith:shortStream];

					verifyValues(stream, @[
						RACTuplePack(valuesOne[0], @"now"),
						RACTuplePack(valuesOne[1], @"later")
					]);
				});

				qck_it(@"should work on infinite streams", ^{
					RACStream *stream = [streamOne zipWith:infiniteStream];
					verifyValues(stream, @[
						RACTuplePack(valuesOne[0], RACUnit.defaultUnit),
						RACTuplePack(valuesOne[1], RACUnit.defaultUnit),
						RACTuplePack(valuesOne[2], RACUnit.defaultUnit)
					]);
				});

				qck_it(@"should handle multiples of the same stream", ^{
					RACStream *stream = [streamOne zipWith:streamOne];
					verifyValues(stream, @[
						RACTuplePack(valuesOne[0], valuesOne[0]),
						RACTuplePack(valuesOne[1], valuesOne[1]),
						RACTuplePack(valuesOne[2], valuesOne[2]),
					]);
				});
			});

			qck_describe(@"+zip:reduce:", ^{
				qck_it(@"should reduce values", ^{
					RACStream *stream = [streamClass zip:threeStreams reduce:^ NSString * (id x, id y, id z) {
						return [NSString stringWithFormat:@"%@ %@ %@", x, y, z];
					}];
					verifyValues(stream, @[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]);
				});

				qck_it(@"should truncate streams", ^{
					RACStream *shortStream = streamWithValues(@[ @"now", @"later" ]);
					NSArray *streams = [threeStreams arrayByAddingObject:shortStream];
					RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id w, id x, id y, id z) {
						return [NSString stringWithFormat:@"%@ %@ %@ %@", w, x, y, z];
					}];
					verifyValues(stream, @[ @"Ada eats fish now", @"Bob cooks bear later" ]);
				});

				qck_it(@"should work on infinite streams", ^{
					NSArray *streams = [threeStreams arrayByAddingObject:infiniteStream];
					RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id w, id x, id y, id z) {
						return [NSString stringWithFormat:@"%@ %@ %@", w, x, y];
					}];
					verifyValues(stream, @[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]);
				});

				qck_it(@"should handle multiples of the same stream", ^{
					NSArray *streams = @[ streamOne, streamOne, streamTwo, streamThree, streamTwo, streamThree ];
					RACStream *stream = [streamClass zip:streams reduce:^ NSString * (id x1, id x2, id y1, id z1, id y2, id z2) {
						return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@", x1, x2, y1, z1, y2, z2];
					}];
					verifyValues(stream, @[ @"Ada Ada eats fish eats fish", @"Bob Bob cooks bear cooks bear", @"Dea Dea jumps rock jumps rock" ]);
				});
			});

			qck_describe(@"+zip:", ^{
				qck_it(@"should make a stream of tuples out of single value", ^{
					RACStream *stream = [streamClass zip:@[ streamOne ]];
					verifyValues(stream, oneStreamTuples);
				});

				qck_it(@"should make a stream of tuples out of an array of streams", ^{
					RACStream *stream = [streamClass zip:threeStreams];
					verifyValues(stream, threeStreamTuples);
				});

				qck_it(@"should make an empty stream if given an empty array", ^{
					RACStream *stream = [streamClass zip:@[]];
					verifyValues(stream, @[]);
				});

				qck_it(@"should make a stream of tuples out of an enumerator of streams", ^{
					RACStream *stream = [streamClass zip:threeStreams.objectEnumerator];
					verifyValues(stream, threeStreamTuples);
				});

				qck_it(@"should make an empty stream if given an empty enumerator", ^{
					RACStream *stream = [streamClass zip:@[].objectEnumerator];
					verifyValues(stream, @[]);
				});
			});
		});

		qck_describe(@"+concat:", ^{
			__block NSArray *streams = nil;
			__block NSArray *result = nil;

			qck_beforeEach(^{
				RACStream *a = [streamClass return:@0];
				RACStream *b = [streamClass empty];
				RACStream *c = streamWithValues(@[ @1, @2, @3 ]);
				RACStream *d = [streamClass return:@4];
				RACStream *e = [streamClass return:@5];
				RACStream *f = [streamClass empty];
				RACStream *g = [streamClass empty];
				RACStream *h = streamWithValues(@[ @6, @7 ]);
				streams = @[ a, b, c, d, e, f, g, h ];
				result = @[ @0, @1, @2, @3, @4, @5, @6, @7 ];
			});

			qck_it(@"should concatenate an array of streams", ^{
				RACStream *stream = [streamClass concat:streams];
				verifyValues(stream, result);
			});

			qck_it(@"should concatenate an enumerator of streams", ^{
				RACStream *stream = [streamClass concat:streams.objectEnumerator];
				verifyValues(stream, result);
			});
		});

		qck_describe(@"scanning", ^{
			NSArray *values = @[ @1, @2, @3, @4 ];

			__block RACStream *stream;

			qck_beforeEach(^{
				stream = streamWithValues(values);
			});

			qck_it(@"should scan", ^{
				RACStream *scanned = [stream scanWithStart:@0 reduce:^(NSNumber *running, NSNumber *next) {
					return @(running.integerValue + next.integerValue);
				}];

				verifyValues(scanned, @[ @1, @3, @6, @10 ]);
			});

			qck_it(@"should scan with index", ^{
				RACStream *scanned = [stream scanWithStart:@0 reduceWithIndex:^(NSNumber *running, NSNumber *next, NSUInteger index) {
					return @(running.integerValue + next.integerValue + (NSInteger)index);
				}];

				verifyValues(scanned, @[ @1, @4, @9, @16 ]);
			});
		});

		qck_describe(@"taking with a predicate", ^{
			NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

			__block RACStream *stream;

			qck_beforeEach(^{
				stream = streamWithValues(values);
			});

			qck_it(@"should take until a predicate is true", ^{
				RACStream *taken = [stream takeUntilBlock:^ BOOL (NSNumber *x) {
					return x.integerValue >= 3;
				}];

				verifyValues(taken, @[ @0, @1, @2 ]);
			});

			qck_it(@"should take while a predicate is true", ^{
				RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue <= 1;
				}];

				verifyValues(taken, @[ @0, @1 ]);
			});

			qck_it(@"should take a full stream", ^{
				RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue <= 10;
				}];

				verifyValues(taken, values);
			});

			qck_it(@"should return an empty stream", ^{
				RACStream *taken = [stream takeWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue < 0;
				}];

				verifyValues(taken, @[]);
			});

			qck_it(@"should terminate an infinite stream", ^{
				RACStream *infiniteCounter = [infiniteStream scanWithStart:@0 reduce:^(NSNumber *running, id _) {
					return @(running.unsignedIntegerValue + 1);
				}];

				RACStream *taken = [infiniteCounter takeWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue <= 5;
				}];

				verifyValues(taken, @[ @1, @2, @3, @4, @5 ]);
			});
		});

		qck_describe(@"skipping with a predicate", ^{
			NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

			__block RACStream *stream;

			qck_beforeEach(^{
				stream = streamWithValues(values);
			});

			qck_it(@"should skip until a predicate is true", ^{
				RACStream *taken = [stream skipUntilBlock:^ BOOL (NSNumber *x) {
					return x.integerValue >= 3;
				}];

				verifyValues(taken, @[ @3, @0, @2, @4 ]);
			});

			qck_it(@"should skip while a predicate is true", ^{
				RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue <= 1;
				}];

				verifyValues(taken, @[ @2, @3, @0, @2, @4 ]);
			});

			qck_it(@"should skip a full stream", ^{
				RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue <= 10;
				}];

				verifyValues(taken, @[]);
			});

			qck_it(@"should finish skipping immediately", ^{
				RACStream *taken = [stream skipWhileBlock:^ BOOL (NSNumber *x) {
					return x.integerValue < 0;
				}];

				verifyValues(taken, values);
			});
		});

		qck_describe(@"-combinePreviousWithStart:reduce:", ^{
			NSArray *values = @[ @1, @2, @3 ];
			__block RACStream *stream;
			qck_beforeEach(^{
				stream = streamWithValues(values);
			});

			qck_it(@"should pass the previous next into the reduce block", ^{
				NSMutableArray *previouses = [NSMutableArray array];
				RACStream *mapped = [stream combinePreviousWithStart:nil reduce:^(id previous, id next) {
					[previouses addObject:previous ?: RACTupleNil.tupleNil];
					return next;
				}];

				verifyValues(mapped, @[ @1, @2, @3 ]);

				NSArray *expected = @[ RACTupleNil.tupleNil, @1, @2 ];
				expect(previouses).to(equal(expected));
			});

			qck_it(@"should send the combined value", ^{
				RACStream *mapped = [stream combinePreviousWithStart:@1 reduce:^(NSNumber *previous, NSNumber *next) {
					return [NSString stringWithFormat:@"%lu - %lu", (unsigned long)previous.unsignedIntegerValue, (unsigned long)next.unsignedIntegerValue];
				}];

				verifyValues(mapped, @[ @"1 - 1", @"1 - 2", @"2 - 3" ]);
			});
		});

		qck_it(@"should reduce tuples", ^{
			RACStream *stream = streamWithValues(@[
				RACTuplePack(@"foo", @"bar"),
				RACTuplePack(@"buzz", @"baz"),
				RACTuplePack(@"", @"_")
			]);

			RACStream *reduced = [stream reduceEach:^(NSString *a, NSString *b) {
				return [a stringByAppendingString:b];
			}];

			verifyValues(reduced, @[ @"foobar", @"buzzbaz", @"_" ]);
		});
	});
}

QuickConfigurationEnd
