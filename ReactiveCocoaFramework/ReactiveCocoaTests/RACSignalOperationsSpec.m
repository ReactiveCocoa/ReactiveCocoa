//
//  RACSignalOperationsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-22.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACPropertySignalExamples.h"
#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSArray+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACEvent.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACTestScheduler.h"
#import "RACTuple.h"

// Set in a beforeAll below.
static NSError *RACSignalTestError;

SpecBegin(RACSignalOperations)

beforeAll(^{
	// We do this instead of a macro to ensure that to.equal() will work
	// correctly (by matching identity), even if -[NSError isEqual:] is broken.
	RACSignalTestError = [NSError errorWithDomain:@"foo" code:100 userInfo:nil];
});

__block RACSignal *infiniteSignal;

beforeEach(^{
	infiniteSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
		while (!subscriber.disposable.disposed) {
			[subscriber sendNext:nil];
		}
	}];
});

describe(@"-concat:", ^{
	it(@"should concatenate two signals", ^{
		RACSignal *signal = [[RACSignal return:@0] concat:[RACSignal return:@1]];
		expect([signal array]).to.equal((@[ @0, @1 ]));
	});

	it(@"should concatenate three signals", ^{
		RACSignal *signal = [[[RACSignal return:@0] concat:[RACSignal return:@1]] concat:[RACSignal return:@2]];
		expect([signal array]).to.equal((@[ @0, @1, @2 ]));
	});

	it(@"should concatenate around an empty signal", ^{
		RACSignal *signal = [[[RACSignal return:@0] concat:[RACSignal empty]] concat:[RACSignal return:@2]];
		expect([signal array]).to.equal((@[ @0, @2 ]));
	});
});

it(@"should flatten", ^{
	RACSignal *signal = [[RACSignal return:[RACSignal return:nil]] flatten];
	expect([signal array]).to.equal((@[ NSNull.null ]));
});

describe(@"-flattenMap:", ^{
	it(@"should return a single mapped result", ^{
		RACSignal *signal = [[RACSignal return:@0] flattenMap:^(NSNumber *value) {
			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSignal return:newValue];
		}];

		expect([signal array]).to.equal((@[ @1 ]));
	});

	it(@"should concatenate the results of mapping multiple values", ^{
		RACSignal *baseSignal = @[ @0, @1 ].rac_signal;
		RACSignal *signal = [baseSignal flattenMap:^(NSNumber *value) {
			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSignal return:newValue];
		}];

		expect([signal array]).to.equal((@[ @1, @2 ]));
	});

	it(@"should concatenate with an empty result from mapping a value", ^{
		RACSignal *baseSignal = @[ @0, @1, @2 ].rac_signal;
		RACSignal *signal = [baseSignal flattenMap:^(NSNumber *value) {
			if (value.integerValue == 1) return [RACSignal empty];

			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSignal return:newValue];
		}];

		expect([signal array]).to.equal((@[ @1, @3 ]));
	});

	it(@"should treat nil signals like empty signals", ^{
		RACSignal *baseSignal = @[ @0, @1, @2 ].rac_signal;
		RACSignal *signal = [baseSignal flattenMap:^ RACSignal * (NSNumber *value) {
			if (value.integerValue == 1) return nil;

			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSignal return:newValue];
		}];

		expect([signal array]).to.equal((@[ @1, @3 ]));
	});
});

it(@"should map", ^{
	RACSignal *baseSignal = @[ @0, @1, @2 ].rac_signal;
	RACSignal *signal = [baseSignal map:^(NSNumber *value) {
		return @(value.integerValue + 1);
	}];

	expect([signal array]).to.equal((@[ @1, @2, @3 ]));
});

it(@"should map and replace", ^{
	RACSignal *baseSignal = @[ @0, @1, @2 ].rac_signal;
	RACSignal *signal = [baseSignal mapReplace:nil];

	expect([signal array]).to.equal((@[ NSNull.null, NSNull.null, NSNull.null ]));
});

it(@"should filter", ^{
	RACSignal *baseSignal = @[ @0, @1, @2, @3, @4, @5, @6 ].rac_signal;
	RACSignal *signal = [baseSignal filter:^ BOOL (NSNumber *value) {
		return value.integerValue % 2 == 0;
	}];

	expect([signal array]).to.equal((@[ @0, @2, @4, @6 ]));
});

describe(@"-ignore:", ^{
	it(@"should ignore a value", ^{
		RACSignal *baseSignal = @[ @0, @1, @2, @3, @4, @5, @6 ].rac_signal;
		RACSignal *signal = [baseSignal ignore:@1];

		expect([signal array]).to.equal((@[ @0, @2, @3, @4, @5, @6 ]));
	});

	it(@"should ignore based on object equality", ^{
		RACSignal *baseSignal = @[ @"0", @"1", @"2", @"3", @"4", @"5", @"6" ].rac_signal;

		NSMutableString *valueToIgnore = [[NSMutableString alloc] init];
		[valueToIgnore appendString:@"1"];
		RACSignal *signal = [baseSignal ignore:valueToIgnore];

		expect([signal array]).to.equal((@[ @"0", @"2", @"3", @"4", @"5", @"6" ]));
	});

	it(@"should ignore nil", ^{
		RACSignal *signal = [[RACSignal
			create:^(id<RACSubscriber> subscriber) {
				[subscriber sendNext:@1];
				[subscriber sendNext:nil];
				[subscriber sendNext:@3];
				[subscriber sendNext:@4];
				[subscriber sendNext:nil];
				[subscriber sendCompleted];
			}]
			ignore:nil];
		
		NSArray *expected = @[ @1, @3, @4 ];
		expect([signal array]).to.equal(expected);
	});
});

it(@"should start with a value", ^{
	RACSignal *signal = [[RACSignal return:@1] startWith:@0];
	expect([signal array]).to.equal((@[ @0, @1 ]));
});

describe(@"-skip:", ^{
	__block NSArray *values;
	__block RACSignal *signal;

	before(^{
		values = @[ @0, @1, @2 ];
		signal = values.rac_signal;
	});

	it(@"should skip any valid number of values", ^{
		for (NSUInteger i = 0; i < values.count; i++) {
			expect([[signal skip:i] array]).to.equal([values subarrayWithRange:NSMakeRange(i, values.count - i)]);
		}
	});

	it(@"should return an empty signal when skipping too many values", ^{
		expect([[signal skip:4] array]).to.equal(@[]);
	});
});

describe(@"-take:", ^{
	describe(@"with three values", ^{
		__block NSArray *values;
		__block RACSignal *signal;

		before(^{
			values = @[ @0, @1, @2 ];
			signal = values.rac_signal;
		});

		it(@"should take any valid number of values", ^{
			for (NSUInteger i = 0; i < values.count; i++) {
				expect([[signal take:i] array]).to.equal([values subarrayWithRange:NSMakeRange(0, i)]);
			}
		});

		it(@"should return the same signal when taking too many values", ^{
			expect([[signal take:4] array]).to.equal(values);
		});
	});

	it(@"should take and terminate from an infinite signal", ^{
		expect([[infiniteSignal take:0] array]).to.equal((@[]));
		expect([[infiniteSignal take:1] array]).to.equal((@[ NSNull.null ]));
		expect([[infiniteSignal take:2] array]).to.equal((@[ NSNull.null, NSNull.null ]));
	});

	it(@"should take and terminate from a single-item signal", ^{
		NSArray *values = @[ NSNull.null ];
		RACSignal *signal = values.rac_signal;
		expect([[signal take:1] array]).to.equal(values);
	});

	it(@"should complete take: even if the original signal doesn't", ^{
		RACSignal *sendOne = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@"foobar"];
		}];

		__block id value = nil;
		__block BOOL completed = NO;
		[[sendOne take:1] subscribeNext:^(id received) {
			value = received;
		} completed:^{
			completed = YES;
		}];

		expect(value).to.equal(@"foobar");
		expect(completed).to.beTruthy();
	});
});

describe(@"zip signal creation methods", ^{
	__block NSArray *valuesOne;

	__block RACSignal *signalOne;
	__block RACSignal *signalTwo;
	__block RACSignal *signalThree;
	__block NSArray *threeSignals;

	__block NSArray *oneSignalTuples;
	__block NSArray *twoSignalTuples;
	__block NSArray *threeSignalTuples;
	
	before(^{
		valuesOne = @[ @"Ada", @"Bob", @"Dea" ];
		NSArray *valuesTwo = @[ @"eats", @"cooks", @"jumps" ];
		NSArray *valuesThree = @[ @"fish", @"bear", @"rock" ];

		signalOne = valuesOne.rac_signal;
		signalTwo = valuesTwo.rac_signal;
		signalThree = valuesThree.rac_signal;
		threeSignals = @[ signalOne, signalTwo, signalThree ];

		oneSignalTuples = @[
			RACTuplePack(valuesOne[0]),
			RACTuplePack(valuesOne[1]),
			RACTuplePack(valuesOne[2]),
		];

		twoSignalTuples = @[
			RACTuplePack(valuesOne[0], valuesTwo[0]),
			RACTuplePack(valuesOne[1], valuesTwo[1]),
			RACTuplePack(valuesOne[2], valuesTwo[2]),
		];

		threeSignalTuples = @[
			RACTuplePack(valuesOne[0], valuesTwo[0], valuesThree[0]),
			RACTuplePack(valuesOne[1], valuesTwo[1], valuesThree[1]),
			RACTuplePack(valuesOne[2], valuesTwo[2], valuesThree[2]),
		];
	});

	describe(@"-zipWith:", ^{
		it(@"should make a signal of tuples", ^{
			RACSignal *signal = [signalOne zipWith:signalTwo];
			expect([signal array]).to.equal((twoSignalTuples));
		});
		
		it(@"should truncate signals", ^{
			RACSignal *shortSignal = @[ @"now", @"later" ].rac_signal;
			RACSignal *signal = [signalOne zipWith:shortSignal];

			NSArray *values = @[
				RACTuplePack(valuesOne[0], @"now"),
				RACTuplePack(valuesOne[1], @"later"),
			];

			expect([signal array]).to.equal(values);
		});
		
		it(@"should work on infinite signals", ^{
			RACSignal *signal = [signalOne zipWith:[infiniteSignal mapReplace:NSNull.null]];
			NSArray *values = @[
				RACTuplePack(valuesOne[0], NSNull.null),
				RACTuplePack(valuesOne[1], NSNull.null),
				RACTuplePack(valuesOne[2], NSNull.null),
			];

			expect([signal array]).to.equal(values);
		});
		
		it(@"should handle multiples of the same signal", ^{
			RACSignal *signal = [signalOne zipWith:signalOne];
			NSArray *values = @[
				RACTuplePack(valuesOne[0], valuesOne[0]),
				RACTuplePack(valuesOne[1], valuesOne[1]),
				RACTuplePack(valuesOne[2], valuesOne[2]),
			];

			expect([signal array]).to.equal(values);
		});
	});
	
	describe(@"+zip:reduce:", ^{
		it(@"should reduce values", ^{
			RACSignal *signal = [RACSignal zip:threeSignals reduce:^ NSString * (id x, id y, id z) {
				return [NSString stringWithFormat:@"%@ %@ %@", x, y, z];
			}];
			expect([signal array]).to.equal((@[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]));
		});
		
		it(@"should truncate signals", ^{
			RACSignal *shortSignal = @[ @"now", @"later" ].rac_signal;
			NSArray *signals = [threeSignals arrayByAddingObject:shortSignal];
			RACSignal *signal = [RACSignal zip:signals reduce:^ NSString * (id w, id x, id y, id z) {
				return [NSString stringWithFormat:@"%@ %@ %@ %@", w, x, y, z];
			}];
			expect([signal array]).to.equal((@[ @"Ada eats fish now", @"Bob cooks bear later" ]));
		});
		
		it(@"should work on infinite signals", ^{
			NSArray *signals = [threeSignals arrayByAddingObject:infiniteSignal];
			RACSignal *signal = [RACSignal zip:signals reduce:^ NSString * (id w, id x, id y, id z) {
				return [NSString stringWithFormat:@"%@ %@ %@", w, x, y];
			}];
			expect([signal array]).to.equal((@[ @"Ada eats fish", @"Bob cooks bear", @"Dea jumps rock" ]));
		});
		
		it(@"should handle multiples of the same signal", ^{
			NSArray *signals = @[ signalOne, signalOne, signalTwo, signalThree, signalTwo, signalThree ];
			RACSignal *signal = [RACSignal zip:signals reduce:^ NSString * (id x1, id x2, id y1, id z1, id y2, id z2) {
				return [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@", x1, x2, y1, z1, y2, z2];
			}];
			expect([signal array]).to.equal((@[ @"Ada Ada eats fish eats fish", @"Bob Bob cooks bear cooks bear", @"Dea Dea jumps rock jumps rock" ]));
		});
	});
	
	describe(@"+zip:", ^{
		__block RACSubject *subject1 = nil;
		__block RACSubject *subject2 = nil;

		__block BOOL hasSentError = NO;
		__block BOOL hasSentCompleted = NO;

		__block RACDisposable *disposable = nil;

		__block void (^send2NextAndErrorTo1)(void) = nil;
		__block void (^send3NextAndErrorTo1)(void) = nil;
		__block void (^send2NextAndCompletedTo2)(void) = nil;
		__block void (^send3NextAndCompletedTo2)(void) = nil;
		
		beforeEach(^{
			send2NextAndErrorTo1 = [^{
				[subject1 sendNext:@1];
				[subject1 sendNext:@2];
				[subject1 sendError:RACSignalTestError];
			} copy];

			send3NextAndErrorTo1 = [^{
				[subject1 sendNext:@1];
				[subject1 sendNext:@2];
				[subject1 sendNext:@3];
				[subject1 sendError:RACSignalTestError];
			} copy];

			send2NextAndCompletedTo2 = [^{
				[subject2 sendNext:@1];
				[subject2 sendNext:@2];
				[subject2 sendCompleted];
			} copy];

			send3NextAndCompletedTo2 = [^{
				[subject2 sendNext:@1];
				[subject2 sendNext:@2];
				[subject2 sendNext:@3];
				[subject2 sendCompleted];
			} copy];

			subject1 = [RACSubject subject];
			subject2 = [RACSubject subject];

			hasSentError = NO;
			hasSentCompleted = NO;

			disposable = [[RACSignal zip:@[ subject1, subject2 ]] subscribeError:^(NSError *error) {
				hasSentError = YES;
			} completed:^{
				hasSentCompleted = YES;
			}];
		});
		
		afterEach(^{
			[disposable dispose];
		});

		it(@"should make a signal of tuples out of single value", ^{
			RACSignal *signal = [RACSignal zip:@[ signalOne ]];
			expect([signal array]).to.equal((oneSignalTuples));
		});

		it(@"should make a signal of tuples out of an array of signals", ^{
			RACSignal *signal = [RACSignal zip:threeSignals];
			expect([signal array]).to.equal((threeSignalTuples));
		});

		it(@"should make an empty signal if given an empty array", ^{
			RACSignal *signal = [RACSignal zip:@[]];
			expect([signal array]).to.equal((@[]));
		});
		
		it(@"should make a signal of tuples out of an enumerator of signals", ^{
			RACSignal *signal = [RACSignal zip:threeSignals.objectEnumerator];
			expect([signal array]).to.equal((threeSignalTuples));
		});
		
		it(@"should make an empty signal if given an empty enumerator", ^{
			RACSignal *signal = [RACSignal zip:@[].objectEnumerator];
			expect([signal array]).to.equal((@[]));
		});
		
		it(@"should complete as soon as no new zipped values are possible", ^{
			[subject1 sendNext:@1];
			[subject2 sendNext:@1];
			expect(hasSentCompleted).to.beFalsy();
			
			[subject1 sendNext:@2];
			[subject1 sendCompleted];
			expect(hasSentCompleted).to.beFalsy();
			
			[subject2 sendNext:@2];
			expect(hasSentCompleted).to.beTruthy();
		});
		
		it(@"outcome should not be dependent on order of signals", ^{
			[subject2 sendCompleted];
			expect(hasSentCompleted).to.beTruthy();
		});
		
		it(@"should forward errors sent earlier than (time-wise) and before (position-wise) a complete", ^{
			send2NextAndErrorTo1();
			send3NextAndCompletedTo2();
			expect(hasSentError).to.beTruthy();
			expect(hasSentCompleted).to.beFalsy();
		});
		
		it(@"should forward errors sent earlier than (time-wise) and after (position-wise) a complete", ^{
			send3NextAndErrorTo1();
			send2NextAndCompletedTo2();
			expect(hasSentError).to.beTruthy();
			expect(hasSentCompleted).to.beFalsy();
		});
		
		it(@"should forward errors sent later than (time-wise) and before (position-wise) a complete", ^{
			send3NextAndCompletedTo2();
			send2NextAndErrorTo1();
			expect(hasSentError).to.beTruthy();
			expect(hasSentCompleted).to.beFalsy();
		});
		
		it(@"should ignore errors sent later than (time-wise) and after (position-wise) a complete", ^{
			send2NextAndCompletedTo2();
			send3NextAndErrorTo1();
			expect(hasSentError).to.beFalsy();
			expect(hasSentCompleted).to.beTruthy();
		});
		
		it(@"should handle signals sending values unevenly", ^{
			__block NSError *receivedError = nil;
			__block BOOL hasCompleted = NO;
			
			RACSubject *a = [RACSubject subject];
			RACSubject *b = [RACSubject subject];
			RACSubject *c = [RACSubject subject];
			
			NSMutableArray *receivedValues = NSMutableArray.array;
			NSArray *expectedValues = nil;
			
			[[RACSignal zip:@[ a, b, c ] reduce:^(NSNumber *a, NSNumber *b, NSNumber *c) {
				return [NSString stringWithFormat:@"%@%@%@", a, b, c];
			}] subscribeNext:^(id x) {
				[receivedValues addObject:x];
			} error:^(NSError *error) {
				receivedError = error;
			} completed:^{
				hasCompleted = YES;
			}];
			
			[a sendNext:@1];
			[a sendNext:@2];
			[a sendNext:@3];
			
			[b sendNext:@1];
			
			[c sendNext:@1];
			[c sendNext:@2];
			
			// a: [===......]
			// b: [=........]
			// c: [==.......]
			
			expectedValues = @[ @"111" ];
			expect(receivedValues).to.equal(expectedValues);
			expect(receivedError).to.beNil();
			expect(hasCompleted).to.beFalsy();
			
			[b sendNext:@2];
			[b sendNext:@3];
			[b sendNext:@4];
			[b sendCompleted];
			
			// a: [===......]
			// b: [====C....]
			// c: [==.......]
			
			expectedValues = @[ @"111", @"222" ];
			expect(receivedValues).to.equal(expectedValues);
			expect(receivedError).to.beNil();
			expect(hasCompleted).to.beFalsy();
			
			[c sendNext:@3];
			[c sendNext:@4];
			[c sendNext:@5];
			[c sendError:RACSignalTestError];
			
			// a: [===......]
			// b: [====C....]
			// c: [=====E...]
			
			expectedValues = @[ @"111", @"222", @"333" ];
			expect(receivedValues).to.equal(expectedValues);
			expect(receivedError).to.equal(RACSignalTestError);
			expect(hasCompleted).to.beFalsy();
			
			[a sendNext:@4];
			[a sendNext:@5];
			[a sendNext:@6];
			[a sendNext:@7];
			
			// a: [=======..]
			// b: [====C....]
			// c: [=====E...]
			
			expectedValues = @[ @"111", @"222", @"333" ];
			expect(receivedValues).to.equal(expectedValues);
			expect(receivedError).to.equal(RACSignalTestError);
			expect(hasCompleted).to.beFalsy();
		});
		
		it(@"should handle multiples of the same side-effecting signal", ^{
			__block NSUInteger counter = 0;
			RACSignal *sideEffectingSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
				++counter;
				[subscriber sendNext:@1];
				[subscriber sendCompleted];
			}];

			RACSignal *combined = [RACSignal zip:@[ sideEffectingSignal, sideEffectingSignal ] reduce:^ NSString * (id x, id y) {
				return [NSString stringWithFormat:@"%@%@", x, y];
			}];
			NSMutableArray *receivedValues = NSMutableArray.array;
			
			expect(counter).to.equal(0);
			
			[combined subscribeNext:^(id x) {
				[receivedValues addObject:x];
			}];
			
			expect(counter).to.equal(2);
			expect(receivedValues).to.equal(@[ @"11" ]);
		});
	});
});

describe(@"+concat:", ^{
	__block NSArray *signals = nil;
	__block NSArray *result = nil;
	
	before(^{
		RACSignal *a = [RACSignal return:@0];
		RACSignal *b = [RACSignal empty];
		RACSignal *c = @[ @1, @2, @3 ].rac_signal;
		RACSignal *d = [RACSignal return:@4];
		RACSignal *e = [RACSignal return:@5];
		RACSignal *f = [RACSignal empty];
		RACSignal *g = [RACSignal empty];
		RACSignal *h = @[ @6, @7 ].rac_signal;
		signals = @[ a, b, c, d, e, f, g, h ];
		result = @[ @0, @1, @2, @3, @4, @5, @6, @7 ];
	});
	
	it(@"should concatenate an array of signals", ^{
		RACSignal *signal = [RACSignal concat:signals];
		expect([signal array]).to.equal((result));
	});
	
	it(@"should concatenate an enumerator of signals", ^{
		RACSignal *signal = [RACSignal concat:signals.objectEnumerator];
		expect([signal array]).to.equal((result));
	});
});

it(@"should scan", ^{
	RACSignal *signal = @[ @1, @2, @3, @4 ].rac_signal;
	RACSignal *scanned = [signal scanWithStart:@0 reduce:^(NSNumber *running, NSNumber *next) {
		return @(running.integerValue + next.integerValue);
	}];

	expect([scanned array]).to.equal((@[ @1, @3, @6, @10 ]));
});

describe(@"taking with a predicate", ^{
	NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

	__block RACSignal *signal;

	before(^{
		signal = values.rac_signal;
	});

	it(@"should take while a predicate is true", ^{
		RACSignal *taken = [signal takeWhile:^ BOOL (NSNumber *x) {
			return x.integerValue <= 1;
		}];

		expect([taken array]).to.equal((@[ @0, @1 ]));
	});

	it(@"should take a full signal", ^{
		RACSignal *taken = [signal takeWhile:^ BOOL (NSNumber *x) {
			return x.integerValue <= 10;
		}];

		expect([taken array]).to.equal((values));
	});

	it(@"should return an empty signal", ^{
		RACSignal *taken = [signal takeWhile:^ BOOL (NSNumber *x) {
			return x.integerValue < 0;
		}];

		expect([taken array]).to.equal((@[]));
	});

	it(@"should terminate an infinite signal", ^{
		RACSignal *infiniteCounter = [infiniteSignal scanWithStart:@0 reduce:^(NSNumber *running, id _) {
			return @(running.unsignedIntegerValue + 1);
		}];

		RACSignal *taken = [infiniteCounter takeWhile:^ BOOL (NSNumber *x) {
			return x.integerValue <= 5;
		}];

		expect([taken array]).to.equal((@[ @1, @2, @3, @4, @5 ]));
	});
});

describe(@"skipping with a predicate", ^{
	NSArray *values = @[ @0, @1, @2, @3, @0, @2, @4 ];

	__block RACSignal *signal;

	before(^{
		signal = values.rac_signal;
	});

	it(@"should skip while a predicate is true", ^{
		RACSignal *taken = [signal skipWhile:^ BOOL (NSNumber *x) {
			return x.integerValue <= 1;
		}];

		expect([taken array]).to.equal((@[ @2, @3, @0, @2, @4 ]));
	});

	it(@"should skip a full signal", ^{
		RACSignal *taken = [signal skipWhile:^ BOOL (NSNumber *x) {
			return x.integerValue <= 10;
		}];

		expect([taken array]).to.equal((@[]));
	});

	it(@"should finish skipping immediately", ^{
		RACSignal *taken = [signal skipWhile:^ BOOL (NSNumber *x) {
			return x.integerValue < 0;
		}];

		expect([taken array]).to.equal((values));
	});
});

describe(@"-combinePreviousWithStart:reduce:", ^{
	NSArray *values = @[ @1, @2, @3 ];
	__block RACSignal *signal;
	beforeEach(^{
		signal = values.rac_signal;
	});

	it(@"should pass the previous next into the reduce block", ^{
		NSMutableArray *previouses = [NSMutableArray array];
		RACSignal *mapped = [signal combinePreviousWithStart:nil reduce:^(id previous, id next) {
			[previouses addObject:previous ?: RACTupleNil.tupleNil];
			return next;
		}];

		expect([mapped array]).to.equal((@[ @1, @2, @3 ]));

		NSArray *expected = @[ RACTupleNil.tupleNil, @1, @2 ];
		expect(previouses).to.equal(expected);
	});

	it(@"should send the combined value", ^{
		RACSignal *mapped = [signal combinePreviousWithStart:@1 reduce:^(NSNumber *previous, NSNumber *next) {
			return [NSString stringWithFormat:@"%lu - %lu", (unsigned long)previous.unsignedIntegerValue, (unsigned long)next.unsignedIntegerValue];
		}];

		expect([mapped array]).to.equal((@[ @"1 - 1", @"1 - 2", @"2 - 3" ]));
	});
});

it(@"should reduce tuples", ^{
	RACSignal *signal = @[
		RACTuplePack(@"foo", @"bar"),
		RACTuplePack(@"buzz", @"baz"),
		RACTuplePack(@"", @"_")
	].rac_signal;

	RACSignal *reduced = [signal reduceEach:^(NSString *a, NSString *b) {
		return [a stringByAppendingString:b];
	}];

	expect([reduced array]).to.equal((@[ @"foobar", @"buzzbaz", @"_" ]));
});

describe(@"-takeUntil:", ^{
	it(@"should support value as trigger", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];

		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];

		[cutOffSubject sendNext:nil];

		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});
    
	it(@"should support completion as trigger", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];
        
		[cutOffSubject sendCompleted];
        
		shouldBeGettingItems = NO;
		[subject sendNext:@"should not go through"];
	});

	it(@"should squelch any values sent immediately upon subscription", ^{
		RACSignal *valueSignal = [RACSignal return:nil];
		RACSignal *cutOffSignal = [RACSignal empty];

		__block BOOL gotNext = NO;
		__block BOOL completed = NO;

		[[valueSignal takeUntil:cutOffSignal] subscribeNext:^(id _) {
			gotNext = YES;
		} completed:^{
			completed = YES;
		}];

		expect(gotNext).to.beFalsy();
		expect(completed).to.beTruthy();
	});
});

describe(@"-takeUntilReplacement:", ^{
	it(@"should forward values from the receiver until it's replaced", ^{
		RACSubject *receiver = [RACSubject subject];
		RACSubject *replacement = [RACSubject subject];

		NSMutableArray *receivedValues = [NSMutableArray array];

		[[receiver takeUntilReplacement:replacement] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		expect(receivedValues).to.equal(@[]);

		[receiver sendNext:@1];
		expect(receivedValues).to.equal(@[ @1 ]);

		[receiver sendNext:@2];
		expect(receivedValues).to.equal((@[ @1, @2 ]));

		[replacement sendNext:@3];
		expect(receivedValues).to.equal((@[ @1, @2, @3 ]));

		[receiver sendNext:@4];
		expect(receivedValues).to.equal((@[ @1, @2, @3 ]));

		[replacement sendNext:@5];
		expect(receivedValues).to.equal((@[ @1, @2, @3, @5 ]));
	});

	it(@"should forward error from the receiver", ^{
		RACSubject *receiver = [RACSubject subject];
		__block BOOL receivedError = NO;

		[[receiver takeUntilReplacement:RACSignal.never] subscribeError:^(NSError *error) {
			receivedError = YES;
		}];

		[receiver sendError:nil];
		expect(receivedError).to.beTruthy();
	});

	it(@"should not forward completed from the receiver", ^{
		RACSubject *receiver = [RACSubject subject];
		__block BOOL receivedCompleted = NO;

		[[receiver takeUntilReplacement:RACSignal.never] subscribeCompleted: ^{
			receivedCompleted = YES;
		}];

		[receiver sendCompleted];
		expect(receivedCompleted).to.beFalsy();
	});

	it(@"should forward error from the replacement signal", ^{
		RACSubject *replacement = [RACSubject subject];
		__block BOOL receivedError = NO;

		[[RACSignal.never takeUntilReplacement:replacement] subscribeError:^(NSError *error) {
			receivedError = YES;
		}];

		[replacement sendError:nil];
		expect(receivedError).to.beTruthy();
	});

	it(@"should forward completed from the replacement signal", ^{
		RACSubject *replacement = [RACSubject subject];
		__block BOOL receivedCompleted = NO;

		[[RACSignal.never takeUntilReplacement:replacement] subscribeCompleted: ^{
			receivedCompleted = YES;
		}];

		[replacement sendCompleted];
		expect(receivedCompleted).to.beTruthy();
	});
	
	it(@"should not forward values from the receiver if both send synchronously", ^{
		RACSignal *receiver = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
		}];

		RACSignal *replacement = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@4];
			[subscriber sendNext:@5];
			[subscriber sendNext:@6];
		}];

		NSMutableArray *receivedValues = [NSMutableArray array];

		[[receiver takeUntilReplacement:replacement] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		expect(receivedValues).to.equal((@[ @4, @5, @6 ]));
	});

	it(@"should dispose of the receiver when it's disposed of", ^{
		__block BOOL receiverDisposed = NO;
		RACSignal *receiver = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				receiverDisposed = YES;
			}]];
		}];

		[[[receiver takeUntilReplacement:RACSignal.never] subscribe:nil] dispose];

		expect(receiverDisposed).to.beTruthy();
	});

	it(@"should dispose of the replacement signal when it's disposed of", ^{
		__block BOOL replacementDisposed = NO;
		RACSignal *replacement = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				replacementDisposed = YES;
			}]];
		}];

		[[[RACSignal.never takeUntilReplacement:replacement] subscribe:nil] dispose];

		expect(replacementDisposed).to.beTruthy();
	});

	it(@"should dispose of the receiver when the replacement signal sends an event", ^{
		__block BOOL receiverDisposed = NO;
		RACSignal *receiver = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				receiverDisposed = YES;
			}]];
		}];

		RACSubject *replacement = [RACSubject subject];
		[[receiver takeUntilReplacement:replacement] subscribe:nil];

		expect(receiverDisposed).to.beFalsy();

		[replacement sendNext:nil];
		
		expect(receiverDisposed).to.beTruthy();
	});
});

describe(@"waiting", ^{
	__block RACSignal *signal = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendNext:@"other value"];
			[subscriber sendCompleted];
		}];
	});
	
	it(@"should return first 'next' value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendCompleted];
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@1);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return first default value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return error with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendError:RACSignalTestError];
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"shouldn't crash when returning an error from a background scheduler", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendError:RACSignalTestError];
			}];
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should terminate the subscription after returning from -firstOrDefault:success:error:", ^{
		__block BOOL disposed = NO;
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@"foobar"];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		expect(signal).notTo.beNil();
		expect(disposed).to.beFalsy();

		expect([signal firstOrDefault:nil success:NULL error:NULL]).to.equal(@"foobar");
		expect(disposed).to.beTruthy();
	});

	it(@"should return YES from -waitUntilCompleted: when successful", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];

		__block NSError *error = nil;
		expect([signal waitUntilCompleted:&error]).to.beTruthy();
		expect(error).to.beNil();
	});

	it(@"should return NO from -waitUntilCompleted: upon error", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendError:RACSignalTestError];
		}];

		__block NSError *error = nil;
		expect([signal waitUntilCompleted:&error]).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should return a delayed value from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal return:@"foobar"] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		BOOL success = NO;
		NSError *error = nil;
		id value = [signal asynchronousFirstOrDefault:nil success:&success error:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(value).to.equal(@"foobar");
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});

	it(@"should return a default value from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal error:RACSignalTestError] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		BOOL success = NO;
		NSError *error = nil;
		id value = [signal asynchronousFirstOrDefault:@"foobar" success:&success error:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(value).to.equal(@"foobar");
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should return a delayed error from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal
			create:^(id<RACSubscriber> subscriber) {
				RACDisposable *disposable = [[RACScheduler scheduler] schedule:^{
					[subscriber sendError:RACSignalTestError];
				}];

				[subscriber.disposable addDisposable:disposable];
			}]
			deliverOn:RACScheduler.mainThreadScheduler];

		__block NSError *error = nil;
		__block BOOL success = NO;
		expect([signal asynchronousFirstOrDefault:nil success:&success error:&error]).to.beNil();

		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should terminate the subscription after returning from -asynchronousFirstOrDefault:success:error:", ^{
		__block BOOL disposed = NO;
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendNext:@"foobar"];
			}];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		expect(signal).notTo.beNil();
		expect(disposed).to.beFalsy();

		expect([signal asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(@"foobar");
		expect(disposed).will.beTruthy();
	});

	it(@"should return a delayed success from -asynchronouslyWaitUntilCompleted:", ^{
		RACSignal *signal = [[RACSignal return:nil] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		NSError *error = nil;
		BOOL success = [signal asynchronouslyWaitUntilCompleted:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
});

describe(@"-repeat", ^{
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACScheduler *scheduler = [RACScheduler scheduler];

		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[scheduler schedule:^{
				if (numberOfSubscriptions == 3) {
					[subscriber sendError:RACSignalTestError];
					return;
				}
				
				numberOfSubscriptions++;
				
				[subscriber sendNext:@"1"];
				[subscriber sendCompleted];
				[subscriber sendError:RACSignalTestError];
			}]];
		}];
		
		__block NSUInteger nextCount = 0;
		__block BOOL gotCompleted = NO;
		[[signal repeat] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			
		} completed:^{
			gotCompleted = YES;
		}];
		
		expect(nextCount).will.equal(3);
		expect(gotCompleted).to.beFalsy();
	});

	it(@"should stop repeating upon error", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendError:RACSignalTestError];
		}];

		NSMutableArray *values = [NSMutableArray array];
		__block NSError *receivedError = nil;
		
		[[signal repeat] subscribeNext:^(id x) {
			[values addObject:x];
		} error:^(NSError *e) {
			receivedError = e;
		}];

		expect(values).will.equal(@[ @1 ]);
		expect(receivedError).to.equal(RACSignalTestError);
	});

	it(@"should stop repeating when disposed", ^{
		__block BOOL disposed = NO;

		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		__block RACDisposable *disposable;
		
		[[signal repeat] subscribeSavingDisposable:^(RACDisposable *d) {
			disposable = d;
		} next:^(id x) {
			[values addObject:x];
			[disposable dispose];
		} error:nil completed:^{
			completed = YES;
		}];

		expect(disposed).will.beTruthy();
		expect(values).to.equal(@[ @1 ]);
		expect(completed).to.beFalsy();
	});

	it(@"should stop repeating when disposed by -take:", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		[[[signal repeat] take:2] subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal((@[ @1, @1 ]));
		expect(completed).to.beTruthy();
	});
});

describe(@"-retry:", ^{
	it(@"should retry N times after error", ^{
		RACScheduler *scheduler = [RACScheduler scheduler];

		NSUInteger retryCount = 3;
		NSUInteger totalTryCount = 1 + retryCount; // First try plus retries.

		__block NSUInteger numberOfSubscriptions = 0;

		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			numberOfSubscriptions++;

			[subscriber.disposable addDisposable:[scheduler schedule:^{
				[subscriber sendNext:@"1"];
				[subscriber sendError:RACSignalTestError];
			}]];
		}];
		
		__block NSUInteger nextCount = 0;
		__block NSError *receivedError = nil;

		[[signal retry:retryCount] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			receivedError = error;
		}];
		
		expect(receivedError).will.equal(RACSignalTestError);
		expect(numberOfSubscriptions).to.equal(totalTryCount);
		expect(nextCount).to.equal(totalTryCount);
	});

	it(@"should stop retrying when disposed", ^{
		__block BOOL disposed = NO;

		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendError:RACSignalTestError];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		__block BOOL errored = NO;
		__block RACDisposable *disposable;
		
		[[signal retry] subscribeSavingDisposable:^(RACDisposable *d) {
			disposable = d;
		} next:^(id x) {
			[values addObject:x];
			[disposable dispose];
		} error:^(NSError *e) {
			errored = YES;
		} completed:^{
			completed = YES;
		}];

		expect(disposed).will.beTruthy();
		expect(values).to.equal(@[ @1 ]);
		expect(completed).to.beFalsy();
		expect(errored).to.beFalsy();
	});

	it(@"should stop retrying when disposed by -take:", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendError:RACSignalTestError];
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		[[[signal retry] take:2] subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal((@[ @1, @1 ]));
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatestWith:", ^{
	__block RACSubject *subject1 = nil;
	__block RACSubject *subject2 = nil;
	__block RACSignal *combined = nil;
	
	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		combined = [RACSignal combineLatest:@[ subject1, subject2 ]];
	});
	
	it(@"should send next only once both signals send next", ^{
		__block RACTuple *tuple;
		
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		expect(tuple).to.beNil();

		[subject1 sendNext:@"1"];
		expect(tuple).to.beNil();

		[subject2 sendNext:@"2"];
		expect(tuple).to.equal(RACTuplePack(@"1", @"2"));
	});
	
	it(@"should send nexts when either signal sends multiple times", ^{
		NSMutableArray *results = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[results addObject:x];
		}];
		
		[subject1 sendNext:@"1"];
		[subject2 sendNext:@"2"];
		
		[subject1 sendNext:@"3"];
		[subject2 sendNext:@"4"];
		
		expect(results[0]).to.equal(RACTuplePack(@"1", @"2"));
		expect(results[1]).to.equal(RACTuplePack(@"3", @"2"));
		expect(results[2]).to.equal(RACTuplePack(@"3", @"4"));
	});
	
	it(@"should complete when only both signals complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();
		
		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beTruthy();
	});
	
	it(@"should error when either signal errors", ^{
		__block NSError *receivedError = nil;
		[combined subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		[subject1 sendError:RACSignalTestError];
		expect(receivedError).to.equal(RACSignalTestError);
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;

		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];
			
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal combineLatest:@[ subject ]];
			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribe:nil];
			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});

	it(@"should combine the same signal", ^{
		RACSignal *combined = [subject1 combineLatestWith:subject1];

		__block RACTuple *tuple;
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		[subject1 sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo", @"foo"));
		
		[subject1 sendNext:@"bar"];
		expect(tuple).to.equal(RACTuplePack(@"bar", @"bar"));
	});
    
	it(@"should combine the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
		}];

		RACSignal *combined = [sideEffectingSignal combineLatestWith:sideEffectingSignal];
		expect(counter).to.equal(0);

		NSMutableArray *receivedValues = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(2);

		NSArray *expected = @[ RACTuplePack(@1, @2) ];
		expect(receivedValues).to.equal(expected);
	});
});

describe(@"+combineLatest:", ^{
	it(@"should return tuples even when only combining one signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block RACTuple *tuple;
		[[RACSignal combineLatest:@[ subject ]] subscribeNext:^(id x) {
			tuple = x;
		}];

		[subject sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo"));
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal combineLatest:@[]];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});

	it(@"should only complete after all its signals complete", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ]];

		__block BOOL completed = NO;
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();

		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beFalsy();

		[subject3 sendCompleted];
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatest:reduce:", ^{
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;

	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		subject3 = [RACSubject subject];
	});

	it(@"should send nils for nil values", ^{
		__block id receivedVal1;
		__block id receivedVal2;
		__block id receivedVal3;

		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^ id (id val1, id val2, id val3) {
			receivedVal1 = val1;
			receivedVal2 = val2;
			receivedVal3 = val3;
			return nil;
		}];

		__block BOOL gotValue = NO;
		[combined subscribeNext:^(id x) {
			gotValue = YES;
		}];

		[subject1 sendNext:nil];
		[subject2 sendNext:nil];
		[subject3 sendNext:nil];

		expect(gotValue).to.beTruthy();
		expect(receivedVal1).to.beNil();
		expect(receivedVal2).to.beNil();
		expect(receivedVal3).to.beNil();
	});

	it(@"should send the return result of the reduce block", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3) {
			return [NSString stringWithFormat:@"%@: %@%@", string1, string2, string3];
		}];

		__block id received;
		[combined subscribeNext:^(id x) {
			received = x;
		}];

		[subject1 sendNext:@"hello"];
		[subject2 sendNext:@"world"];
		[subject3 sendNext:@"!!1"];

		expect(received).to.equal(@"hello: world!!1");
	});
	
	it(@"should handle multiples of the same signals", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject1, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3, NSString *string4) {
			return [NSString stringWithFormat:@"%@ : %@ = %@ : %@", string1, string2, string3, string4];
		}];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		[subject1 sendNext:@"apples"];
		expect(receivedValues.lastObject).to.beNil();
		
		[subject2 sendNext:@"oranges"];
		expect(receivedValues.lastObject).to.beNil();

		[subject3 sendNext:@"cattle"];
		expect(receivedValues.lastObject).to.equal(@"apples : oranges = apples : cattle");
		
		[subject1 sendNext:@"horses"];
		expect(receivedValues.lastObject).to.equal(@"horses : oranges = horses : cattle");
	});
    
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
		}];

		RACSignal *combined = [RACSignal combineLatest:@[ sideEffectingSignal, sideEffectingSignal, sideEffectingSignal ] reduce:^(id x, id y, id z) {
			return [NSString stringWithFormat:@"%@%@%@", x, y, z];
		}];

		NSMutableArray *receivedValues = [NSMutableArray array];
		expect(counter).to.equal(0);
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(3);
		expect(receivedValues).to.equal(@[ @"123" ]);
	});
});

describe(@"distinctUntilChanged", ^{
	it(@"should only send values that are distinct from the previous value", ^{
		RACSignal *sub = [[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@2];
			[subscriber sendNext:@1];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
		}] distinctUntilChanged];
		
		NSArray *values = sub.array;
		NSArray *expected = @[ @1, @2, @1 ];
		expect(values).to.equal(expected);
	});

	it(@"shouldn't consider nils to always be distinct", ^{
		RACSignal *sub = [[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
		}] distinctUntilChanged];
		
		NSArray *values = sub.array;
		NSArray *expected = @[ @1, [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});

	it(@"should consider initial nil to be distinct", ^{
		RACSignal *sub = [[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
		}] distinctUntilChanged];
		
		NSArray *values = sub.array;
		NSArray *expected = @[ [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-setKeyPath:onObject:", ^{
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal) {
		[signal setKeyPath:keyPath onObject:testObject nilValue:nilValue];
	};

	itShouldBehaveLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});

	it(@"shouldn't send values to dealloc'd objects", ^{
		RACSubject *subject = [RACSubject subject];
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[subject setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
			expect(testObject.objectValue).to.beNil();

			[subject sendNext:@1];
			expect(testObject.objectValue).to.equal(@1);

			[subject sendNext:@2];
			expect(testObject.objectValue).to.equal(@2);
		}

		// This shouldn't do anything.
		[subject sendNext:@3];
	});

	it(@"should allow a new derivation after the signal's completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject1 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
		[subject1 sendCompleted];

		RACSubject *subject2 = [RACSubject subject];
		// This will assert if the previous completion didn't dispose of the
		// subscription.
		[subject2 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
	});

	it(@"should set the given value when nil is received", ^{
		RACSubject *subject = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject setKeyPath:@keypath(testObject.integerValue) onObject:testObject nilValue:@5];

		[subject sendNext:@1];
		expect(testObject.integerValue).to.equal(1);

		[subject sendNext:nil];
		expect(testObject.integerValue).to.equal(5);

		[subject sendCompleted];
		expect(testObject.integerValue).to.equal(5);
	});
});

describe(@"-merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSignal *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [sub1 merge:sub2];
	});

	it(@"should send all values from both signals", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[sub1 sendError:RACSignalTestError];
		expect(errorReceived).to.equal(RACSignalTestError);
	});

	it(@"should complete only after both signals complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete only after both signals complete for any number of subscribers", ^{
		__block BOOL completed1 = NO;
		__block BOOL completed2 = NO;
		[merged subscribeCompleted:^{
			completed1 = YES;
		}];

		[merged subscribeCompleted:^{
			completed2 = YES;
		}];

		expect(completed1).to.beFalsy();
		expect(completed2).to.beFalsy();

		[sub1 sendCompleted];
		[sub2 sendCompleted];
		expect(completed1).to.beTruthy();
		expect(completed2).to.beTruthy();
	});
});

describe(@"+merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSignal *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [RACSignal merge:@[ sub1, sub2 ].objectEnumerator];
	});

	it(@"should send all values from both signals", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[sub1 sendError:RACSignalTestError];
		expect(errorReceived).to.equal(RACSignalTestError);
	});

	it(@"should complete only after both signals complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal merge:@[].objectEnumerator];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});

	it(@"should complete only after both signals complete for any number of subscribers", ^{
		__block BOOL completed1 = NO;
		__block BOOL completed2 = NO;
		[merged subscribeCompleted:^{
			completed1 = YES;
		}];

		[merged subscribeCompleted:^{
			completed2 = YES;
		}];

		expect(completed1).to.beFalsy();
		expect(completed2).to.beFalsy();

		[sub1 sendCompleted];
		[sub2 sendCompleted];
		expect(completed1).to.beTruthy();
		expect(completed2).to.beTruthy();
	});
});

describe(@"-switchToLatest", ^{
	__block RACSubject *subject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		subject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[subject switchToLatest] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should send values from the most recent signal", ^{
		[subject sendNext:[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
		}]];

		[subject sendNext:[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
		}]];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send errors from the most recent signal", ^{
		[subject sendNext:[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		}]];

		expect(lastError).notTo.beNil();
	});

	it(@"should not send completed if only the switching signal completes", ^{
		[subject sendNext:RACSignal.never];

		expect(completed).to.beFalsy();

		[subject sendCompleted];
		expect(completed).to.beFalsy();
	});
	
	it(@"should send completed when the switching signal completes and the last sent signal does", ^{
		[subject sendNext:RACSignal.empty];
		
		expect(completed).to.beFalsy();
		
		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should accept nil signals", ^{
		[subject sendNext:nil];
		[subject sendNext:[RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
		}]];

		NSArray *expected = @[ @1, @2 ];
		expect(values).to.equal(expected);
	});

	it(@"should return a cold signal", ^{
		__block NSUInteger subscriptions = 0;
		RACSignal *signalOfSignals = [RACSignal create:^(id<RACSubscriber> subscriber) {
			subscriptions++;
			[subscriber sendNext:[RACSignal empty]];
		}];

		RACSignal *switched = [signalOfSignals switchToLatest];

		[switched subscribe:nil];
		expect(subscriptions).to.equal(1);

		[switched subscribe:nil];
		expect(subscriptions).to.equal(2);
	});
});

describe(@"+switch:cases:default:", ^{
	__block RACSubject *keySubject;

	__block RACSubject *subjectZero;
	__block RACSubject *subjectOne;
	__block RACSubject *subjectTwo;

	__block RACSubject *defaultSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		keySubject = [RACSubject subject];

		subjectZero = [RACSubject subject];
		subjectOne = [RACSubject subject];
		subjectTwo = [RACSubject subject];

		defaultSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;
	});

	describe(@"switching between values with a default", ^{
		__block RACSignal *switchSignal;

		beforeEach(^{
			switchSignal = [RACSignal switch:keySubject cases:@{
				@0: subjectZero,
				@1: subjectOne,
				@2: subjectTwo,
			} default:[RACSignal never]];

			[switchSignal subscribeNext:^(id x) {
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				[values addObject:x];
			} error:^(NSError *error) {
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				lastError = error;
			} completed:^{
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				completed = YES;
			}];
		});

		it(@"should not send any values before a key is sent", ^{
			[subjectZero sendNext:nil];
			[subjectOne sendNext:nil];
			[subjectTwo sendNext:nil];

			expect(values).to.equal(@[]);
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();
		});

		it(@"should send events based on the latest key", ^{
			[keySubject sendNext:@0];

			[subjectZero sendNext:@"zero"];
			[subjectZero sendNext:@"zero"];
			[subjectOne sendNext:@"one"];
			[subjectTwo sendNext:@"two"];

			NSArray *expected = @[ @"zero", @"zero" ];
			expect(values).to.equal(expected);

			[keySubject sendNext:@1];

			[subjectZero sendNext:@"zero"];
			[subjectOne sendNext:@"one"];
			[subjectTwo sendNext:@"two"];

			expected = @[ @"zero", @"zero", @"one" ];
			expect(values).to.equal(expected);

			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[keySubject sendNext:@2];

			[subjectZero sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[subjectOne sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			expect(lastError).to.beNil();

			[subjectTwo sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			expect(lastError).notTo.beNil();
		});

		it(@"should not send completed when only the key signal completes", ^{
			[keySubject sendNext:@0];
			[subjectZero sendNext:@"zero"];
			[keySubject sendCompleted];

			expect(values).to.equal(@[ @"zero" ]);
			expect(completed).to.beFalsy();
		});

		it(@"should send completed when the key signal and the latest sent signal complete", ^{
			[keySubject sendNext:@0];
			[subjectZero sendNext:@"zero"];
			[keySubject sendCompleted];
			[subjectZero sendCompleted];

			expect(values).to.equal(@[ @"zero" ]);
			expect(completed).to.beTruthy();
		});
	});

	it(@"should use the default signal if key that was sent does not have an associated signal", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				@0: subjectZero,
				@1: subjectOne,
			}
			default:defaultSubject]
			subscribeNext:^(id x) {
				[values addObject:x];
			}];

		[keySubject sendNext:@"not a valid key"];
		[defaultSubject sendNext:@"default"];

		expect(values).to.equal(@[ @"default" ]);

		[keySubject sendNext:nil];
		[defaultSubject sendNext:@"default"];

		expect(values).to.equal((@[ @"default", @"default" ]));
	});

	it(@"should send an error if key that was sent does not have an associated signal and there's no default", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				@0: subjectZero,
				@1: subjectOne,
			}
			default:nil]
			subscribeNext:^(id x) {
				[values addObject:x];
			} error:^(NSError *error) {
				lastError = error;
			}];

		[keySubject sendNext:@0];
		[subjectZero sendNext:@"zero"];

		expect(values).to.equal(@[ @"zero" ]);
		expect(lastError).to.beNil();

		[keySubject sendNext:nil];

		expect(values).to.equal(@[ @"zero" ]);
		expect(lastError).notTo.beNil();
		expect(lastError.domain).to.equal(RACSignalErrorDomain);
		expect(lastError.code).to.equal(RACSignalErrorNoMatchingCase);
	});

	it(@"should match RACTupleNil case when a nil value is sent", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				RACTupleNil.tupleNil: subjectZero,
			}
			default:defaultSubject]
			subscribeNext:^(id x) {
				[values addObject:x];
			}];

		[keySubject sendNext:nil];
		[subjectZero sendNext:@"zero"];
		expect(values).to.equal(@[ @"zero" ]);
	});
});

describe(@"+if:then:else", ^{
	__block RACSubject *boolSubject;
	__block RACSubject *trueSubject;
	__block RACSubject *falseSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		boolSubject = [RACSubject subject];
		trueSubject = [RACSubject subject];
		falseSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[RACSignal if:boolSubject then:trueSubject else:falseSubject] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should not send any values before a boolean is sent", ^{
		[trueSubject sendNext:nil];
		[falseSubject sendNext:nil];

		expect(values).to.equal(@[]);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();
	});

	it(@"should send events based on the latest boolean", ^{
		[boolSubject sendNext:@YES];

		[trueSubject sendNext:@"foo"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"bar"];

		NSArray *expected = @[ @"foo", @"bar" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[boolSubject sendNext:@NO];

		[trueSubject sendNext:@"baz"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"barfoo"];

		expected = @[ @"foo", @"bar", @"buzz" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[trueSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).to.beNil();

		[falseSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).notTo.beNil();
	});

	it(@"should not send completed when only the BOOL signal completes", ^{
		[boolSubject sendNext:@YES];
		[trueSubject sendNext:@"foo"];
		[boolSubject sendCompleted];
		
		expect(values).to.equal(@[ @"foo" ]);
		expect(completed).to.beFalsy();
	});

	it(@"should send completed when the BOOL signal and the latest sent signal complete", ^{
		[boolSubject sendNext:@YES];
		[trueSubject sendNext:@"foo"];
		[trueSubject sendCompleted];
		[boolSubject sendCompleted];

		expect(values).to.equal(@[ @"foo" ]);
		expect(completed).to.beTruthy();
	});
});

describe(@"+interval:onScheduler: and +interval:onScheduler:withLeeway:", ^{
	static const NSTimeInterval interval = 0.1;
	static const NSTimeInterval leeway = 0.2;
	
	__block void (^testTimer)(RACSignal *, NSNumber *, NSNumber *) = nil;
	
	before(^{
		testTimer = [^(RACSignal *timer, NSNumber *minInterval, NSNumber *leeway) {
			__block NSUInteger nextsReceived = 0;

			NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
			[[timer take:3] subscribeNext:^(NSDate *date) {
				++nextsReceived;

				NSTimeInterval currentTime = date.timeIntervalSinceReferenceDate;

				// Uniformly distribute the expected interval for all
				// received values. We do this instead of saving a timestamp
				// because a delayed interval may cause the _next_ value to
				// send sooner than the interval.
				NSTimeInterval expectedMinInterval = minInterval.doubleValue * nextsReceived;
				NSTimeInterval expectedMaxInterval = expectedMinInterval + leeway.doubleValue * 3 + 0.05;

				expect(currentTime - startTime).beGreaterThanOrEqualTo(expectedMinInterval);
				expect(currentTime - startTime).beLessThanOrEqualTo(expectedMaxInterval);
			}];
			
			expect(nextsReceived).will.equal(3);
		} copy];
	});
	
	describe(@"+interval:onScheduler:", ^{
		it(@"should work on the main thread scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:RACScheduler.mainThreadScheduler], @(interval), @0);
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:[RACScheduler scheduler]], @(interval), @0);
		});
	});
	
	describe(@"+interval:onScheduler:withLeeway:", ^{
		it(@"should work on the main thread scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:RACScheduler.mainThreadScheduler withLeeway:leeway], @(interval), @(leeway));
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:[RACScheduler scheduler] withLeeway:leeway], @(interval), @(leeway));
		});
	});
});

describe(@"-timeout:onScheduler:", ^{
	__block RACSubject *subject;

	beforeEach(^{
		subject = [RACSubject subject];
	});

	it(@"should time out", ^{
		RACTestScheduler *scheduler = [[RACTestScheduler alloc] init];

		__block NSError *receivedError = nil;
		[[subject timeout:1 onScheduler:scheduler] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		expect(receivedError).to.beNil();

		[scheduler stepAll];
		expect(receivedError).willNot.beNil();
		expect(receivedError.domain).to.equal(RACSignalErrorDomain);
		expect(receivedError.code).to.equal(RACSignalErrorTimedOut);
	});

	it(@"should pass through events while not timed out", ^{
		__block id next = nil;
		__block BOOL completed = NO;
		[[subject timeout:1 onScheduler:RACScheduler.mainThreadScheduler] subscribeNext:^(id x) {
			next = x;
		} completed:^{
			completed = YES;
		}];

		[subject sendNext:@"foobar"];
		expect(next).to.equal(@"foobar");

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should not time out after disposal", ^{
		RACTestScheduler *scheduler = [[RACTestScheduler alloc] init];

		__block NSError *receivedError = nil;
		RACDisposable *disposable = [[subject timeout:1 onScheduler:scheduler] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		[disposable dispose];
		[scheduler stepAll];
		expect(receivedError).to.beNil();
	});
});

describe(@"-delay:", ^{
	__block RACSubject *subject;
	__block RACSignal *delayedSignal;

	beforeEach(^{
		subject = [RACSubject subject];
		delayedSignal = [subject delay:0];
	});

	it(@"should delay nexts", ^{
		__block id next = nil;
		[delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];
		expect(next).to.beNil();
		expect(next).will.equal(@"foo");
	});

	it(@"should delay completed", ^{
		__block BOOL completed = NO;
		[delayedSignal subscribeCompleted:^{
			completed = YES;
		}];

		[subject sendCompleted];
		expect(completed).to.beFalsy();
		expect(completed).will.beTruthy();
	});

	it(@"should not delay errors", ^{
		__block NSError *error = nil;
		[delayedSignal subscribeError:^(NSError *e) {
			error = e;
		}];

		[subject sendError:RACSignalTestError];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should cancel delayed events when disposed", ^{
		__block id next = nil;
		RACDisposable *disposable = [delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];

		__block BOOL done = NO;
		[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(next).to.beNil();
	});
});

describe(@"-catch:", ^{
	it(@"should subscribe to ensuing signal on error", ^{
		RACSubject *subject = [RACSubject subject];

		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal return:@41];
		}];

		__block id value = nil;
		[signal subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendError:RACSignalTestError];
		expect(value).to.equal(@41);
	});

	it(@"should prevent source error from propagating", ^{
		RACSubject *subject = [RACSubject subject];

		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal empty];
		}];

		__block BOOL errorReceived = NO;
		[signal subscribeError:^(NSError *error) {
			errorReceived = YES;
		}];

		[subject sendError:RACSignalTestError];
		expect(errorReceived).to.beFalsy();
	});

	it(@"should propagate error from ensuing signal", ^{
		RACSubject *subject = [RACSubject subject];

		NSError *secondaryError = [NSError errorWithDomain:@"bubs" code:41 userInfo:nil];
		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal error:secondaryError];
		}];

		__block NSError *errorReceived = nil;
		[signal subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[subject sendError:RACSignalTestError];
		expect(errorReceived).to.equal(secondaryError);
	});

	it(@"should dispose ensuing signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block BOOL disposed = NO;
		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal create:^(id<RACSubscriber> subscriber) {
				[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
					disposed = YES;
				}]];
			}];
		}];

		RACDisposable *disposable = [signal subscribe:nil];
		[subject sendError:RACSignalTestError];
		[disposable dispose];

		expect(disposed).will.beTruthy();
	});
});

describe(@"-try:", ^{
	__block RACSubject *subject;
	__block NSError *receivedError;
	__block NSMutableArray *nextValues;
	__block BOOL completed;
	
	beforeEach(^{
		subject = [RACSubject subject];
		nextValues = [NSMutableArray array];
		completed = NO;
		receivedError = nil;
		
		[[subject try:^(NSString *value, NSError **error) {
			if (value != nil) return YES;
			
			if (error != nil) *error = RACSignalTestError;
			
			return NO;
		}] subscribeNext:^(id x) {
			[nextValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			completed = YES;
		}];
	});
	
	it(@"should pass values while YES is returned from the tryBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:@"baz"];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo", @"bar", @"baz", @"buzz" ];
		
		expect(receivedError).to.beNil();
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beTruthy();
	});
	
	it(@"should pass values until NO is returned from the tryBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:nil];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo", @"bar" ];
		
		expect(receivedError).to.equal(RACSignalTestError);
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beFalsy();
	});
});

describe(@"-tryMap:", ^{
	__block RACSubject *subject;
	__block NSError *receivedError;
	__block NSMutableArray *nextValues;
	__block BOOL completed;
	
	beforeEach(^{
		subject = [RACSubject subject];
		nextValues = [NSMutableArray array];
		completed = NO;
		receivedError = nil;
		
		[[subject tryMap:^ id (NSString *value, NSError **error) {
			if (value != nil) return [NSString stringWithFormat:@"%@_a", value];
			
			if (error != nil) *error = RACSignalTestError;

			return nil;
		}] subscribeNext:^(id x) {
			[nextValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			completed = YES;
		}];
	});
	
	it(@"should map values with the mapBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:@"baz"];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];

		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo_a", @"bar_a", @"baz_a", @"buzz_a" ];
		
		expect(receivedError).to.beNil();
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beTruthy();
	});
	
	it(@"should map values with the mapBlock, until the mapBlock returns nil", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:nil];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo_a", @"bar_a" ];
		
		expect(receivedError).to.equal(RACSignalTestError);
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beFalsy();
	});
});

describe(@"-throttleDiscardingEarliest:", ^{
	__block RACSubject *subject;
	__block RACSignal *throttledSignal;

	beforeEach(^{
		subject = [RACSubject subject];
		throttledSignal = [subject throttleDiscardingEarliest:0];
	});

	it(@"should throttle nexts", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[throttledSignal subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		expect(valuesReceived).to.equal(@[]);

		NSArray *expected = @[ @"bar" ];
		expect(valuesReceived).will.equal(expected);

		[subject sendNext:@"buzz"];
		expect(valuesReceived).to.equal(expected);

		expected = @[ @"bar", @"buzz" ];
		expect(valuesReceived).will.equal(expected);
	});

	it(@"should forward completed immediately", ^{
		__block BOOL completed = NO;
		[throttledSignal subscribeCompleted:^{
			completed = YES;
		}];

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should forward errors immediately", ^{
		__block NSError *error = nil;
		[throttledSignal subscribeError:^(NSError *e) {
			error = e;
		}];

		[subject sendError:RACSignalTestError];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should cancel future nexts when disposed", ^{
		__block id next = nil;
		RACDisposable *disposable = [throttledSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];

		__block BOOL done = NO;
		[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(next).to.beNil();
	});
});

describe(@"-sample:", ^{
	it(@"should send the latest value when the sampler signal fires", ^{
		RACSubject *subject = [RACSubject subject];
		RACSubject *sampleSubject = [RACSubject subject];
		RACSignal *sampled = [subject sample:sampleSubject];
		NSMutableArray *values = [NSMutableArray array];
		[sampled subscribeNext:^(id x) {
			[values addObject:x];
		}];
		
		[sampleSubject sendNext:nil];
		expect(values).to.equal(@[]);
		
		[subject sendNext:@1];
		[subject sendNext:@2];
		expect(values).to.equal(@[]);

		[sampleSubject sendNext:nil];
		NSArray *expected = @[ @2 ];
		expect(values).to.equal(expected);

		[subject sendNext:@3];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:nil];
		expected = @[ @2, @3 ];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:nil];
		expected = @[ @2, @3, @3 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-collect", ^{
	__block RACSubject *subject;
	__block RACSignal *collected;

	__block id value;
	__block BOOL hasCompleted;

	beforeEach(^{
		subject = [RACSubject subject];
		collected = [subject collect];
		
		value = nil;
		hasCompleted = NO;
		
		[collected subscribeNext:^(id x) {
			value = x;
		} completed:^{
			hasCompleted = YES;
		}];
	});
	
	it(@"should send a single array when the original signal completes", ^{
		NSArray *expected = @[ @1, @2, @3 ];

		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendNext:@3];
		expect(value).to.beNil();

		[subject sendCompleted];
		expect(value).to.equal(expected);
		expect(hasCompleted).to.beTruthy();
	});

	it(@"should add NSNull to an array for nil values", ^{
		NSArray *expected = @[ NSNull.null, @1, NSNull.null ];
		
		[subject sendNext:nil];
		[subject sendNext:@1];
		[subject sendNext:nil];
		expect(value).to.beNil();
		
		[subject sendCompleted];
		expect(value).to.equal(expected);
		expect(hasCompleted).to.beTruthy();
	});
});

describe(@"-bufferWithTime:", ^{
	__block RACTestScheduler *scheduler;

	__block RACSubject *input;
	__block RACSignal *bufferedInput;
	__block RACTuple *latestValue;

	beforeEach(^{
		scheduler = [[RACTestScheduler alloc] init];

		input = [RACSubject subject];
		bufferedInput = [input bufferWithTime:1 onScheduler:scheduler];
		latestValue = nil;

		[bufferedInput subscribeNext:^(RACTuple *x) {
			latestValue = x;
		}];
	});

	it(@"should buffer nexts", ^{
		[input sendNext:@1];
		[input sendNext:@2];

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));
		
		[input sendNext:@3];
		[input sendNext:@4];

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@3, @4));
	});

	it(@"should not perform buffering until a value is sent", ^{
		[input sendNext:@1];
		[input sendNext:@2];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));
		
		[input sendNext:@3];
		[input sendNext:@4];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@3, @4));
	});

	it(@"should flush any buffered nexts upon completion", ^{
		[input sendNext:@1];
		[input sendCompleted];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1));
	});

	it(@"should support NSNull values", ^{
		[input sendNext:NSNull.null];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(NSNull.null));
	});

	it(@"should buffer nil values", ^{
		[input sendNext:nil];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(nil));
	});
});

describe(@"-concat", ^{
	__block RACSignal *oneSignal;
	__block RACSignal *twoSignal;
	__block RACSignal *threeSignal;

	__block RACSignal *errorSignal;
	__block RACSignal *completedSignal;

	beforeEach(^{
		oneSignal = [RACSignal return:@1];
		twoSignal = [RACSignal return:@2];
		threeSignal = [RACSignal return:@3];

		errorSignal = [RACSignal error:RACSignalTestError];
		completedSignal = RACSignal.empty;
	});

	it(@"should concatenate the values of inner signals", ^{
		RACSignal *signals = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:oneSignal];
			[subscriber sendNext:twoSignal];
			[subscriber sendNext:completedSignal];
			[subscriber sendNext:threeSignal];
		}];

		NSMutableArray *values = [NSMutableArray array];
		[[signals concat] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		NSArray *expected = @[ @1, @2, @3 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete only after all signals complete", ^{
		RACSignal *valuesSignal = @[ @1, @2 ].rac_signal;
		RACSignal *signals = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:valuesSignal];
			[subscriber sendCompleted];
		}];

		NSArray *expected = @[ @1, @2 ];
		expect([[signals concat] array]).to.equal(expected);
	});

	it(@"should pass through errors", ^{
		RACSignal *signals = [RACSignal return:errorSignal];
		
		NSError *error = nil;
		[[signals concat] firstOrDefault:nil success:NULL error:&error];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should concat signals sent later", ^{
		RACSubject *subject = [RACSubject subject];

		NSMutableArray *values = [NSMutableArray array];
		[[[subject
			startWith:oneSignal]
			concat]
			subscribeNext:^(id x) {
				[values addObject:x];
			}];

		NSArray *expected = @[ @1 ];
		expect(values).to.equal(expected);

		[subject sendNext:[twoSignal delay:0]];

		expected = @[ @1, @2 ];
		expect(values).will.equal(expected);

		[subject sendNext:threeSignal];

		expected = @[ @1, @2, @3 ];
		expect(values).to.equal(expected);
	});

	it(@"should dispose the current signal", ^{
		__block BOOL disposed = NO;
		RACSignal *innerSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		RACSignal *signals = [RACSignal return:innerSignal];

		RACDisposable *concatDisposable = [[signals concat] subscribe:nil];
		expect(disposed).notTo.beTruthy();

		[concatDisposable dispose];
		expect(disposed).to.beTruthy();
	});

	it(@"should dispose later signals", ^{
		__block BOOL disposed = NO;
		RACSignal *laterSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}];

		RACSubject *firstSignal = [RACSubject subject];
		RACSignal *outerSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:firstSignal];
			[subscriber sendNext:laterSignal];
		}];

		RACDisposable *concatDisposable = [[outerSignal concat] subscribe:nil];

		[firstSignal sendCompleted];
		expect(disposed).notTo.beTruthy();

		[concatDisposable dispose];
		expect(disposed).to.beTruthy();
	});
});

describe(@"-doFinished:", ^{
	__block RACSubject *subject;

	__block BOOL finishedInvoked;
	__block RACSignal *signal;

	beforeEach(^{
		subject = [RACSubject subject];
		
		finishedInvoked = NO;
		signal = [subject doFinished:^{
			finishedInvoked = YES;
		}];
	});

	it(@"should not run block without a subscription", ^{
		[subject sendCompleted];
		expect(finishedInvoked).to.beFalsy();
	});

	describe(@"with a subscription", ^{
		__block RACDisposable *disposable;

		beforeEach(^{
			disposable = [signal subscribe:nil];
		});
		
		afterEach(^{
			[disposable dispose];
		});

		it(@"should not run upon next", ^{
			[subject sendNext:nil];
			expect(finishedInvoked).to.beFalsy();
		});

		it(@"should run upon completed", ^{
			[subject sendCompleted];
			expect(finishedInvoked).to.beTruthy();
		});

		it(@"should run upon error", ^{
			[subject sendError:nil];
			expect(finishedInvoked).to.beTruthy();
		});
	});
});

describe(@"-doDisposed:", ^{
	__block RACSubject *subject;

	__block BOOL disposedInvoked;
	__block RACSignal *signal;

	beforeEach(^{
		subject = [RACSubject subject];
		
		disposedInvoked = NO;
		signal = [subject doDisposed:^{
			disposedInvoked = YES;
		}];
	});

	it(@"should not run block without a subscription", ^{
		[subject sendCompleted];
		expect(disposedInvoked).to.beFalsy();
	});

	describe(@"with a subscription", ^{
		__block RACDisposable *disposable;

		beforeEach(^{
			disposable = [signal subscribe:nil];
		});

		it(@"should not run upon next", ^{
			[subject sendNext:nil];
			expect(disposedInvoked).to.beFalsy();
		});

		it(@"should run upon completed", ^{
			[subject sendCompleted];
			expect(disposedInvoked).to.beTruthy();
		});

		it(@"should run upon error", ^{
			[subject sendError:nil];
			expect(disposedInvoked).to.beTruthy();
		});

		it(@"should run upon manual disposal", ^{
			[disposable dispose];
			expect(disposedInvoked).to.beTruthy();
		});
	});
});

describe(@"-ignoreValues", ^{
	__block RACSubject *subject;

	__block BOOL gotNext;
	__block BOOL gotCompleted;
	__block NSError *receivedError;

	beforeEach(^{
		subject = [RACSubject subject];

		gotNext = NO;
		gotCompleted = NO;
		receivedError = nil;

		[[subject ignoreValues] subscribeNext:^(id _) {
			gotNext = YES;
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			gotCompleted = YES;
		}];
	});

	it(@"should skip nexts and pass through completed", ^{
		[subject sendNext:nil];
		[subject sendCompleted];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beTruthy();
		expect(receivedError).to.beNil();
	});

	it(@"should skip nexts and pass through errors", ^{
		[subject sendNext:nil];
		[subject sendError:RACSignalTestError];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beFalsy();
		expect(receivedError).to.equal(RACSignalTestError);
	});
});

describe(@"-materialize", ^{
	it(@"should convert nexts and completed into RACEvents", ^{
		NSArray *events = [[[RACSignal return:nil] materialize] array];
		NSArray *expected = @[
			[RACEvent eventWithValue:nil],
			RACEvent.completedEvent
		];

		expect(events).to.equal(expected);
	});

	it(@"should convert errors into RACEvents and complete", ^{
		NSArray *events = [[[RACSignal error:RACSignalTestError] materialize] array];
		NSArray *expected = @[ [RACEvent eventWithError:RACSignalTestError] ];
		expect(events).to.equal(expected);
	});
});

describe(@"-dematerialize", ^{
	it(@"should convert nexts from RACEvents", ^{
		RACSignal *events = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
		}];

		NSArray *expected = @[ @1, @2 ];
		expect([[events dematerialize] array]).to.equal(expected);
	});

	it(@"should convert completed from a RACEvent", ^{
		RACSignal *events = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:RACEvent.completedEvent];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
		}];

		NSArray *expected = @[ @1 ];
		expect([[events dematerialize] array]).to.equal(expected);
	});

	it(@"should convert error from a RACEvent", ^{
		RACSignal *events = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithError:RACSignalTestError]];
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendCompleted];
		}];

		__block NSError *error = nil;
		expect([[events dematerialize] firstOrDefault:nil success:NULL error:&error]).to.beNil();
		expect(error).to.equal(RACSignalTestError);
	});
});

describe(@"-not", ^{
	it(@"should invert every BOOL sent", ^{
		NSArray *inputs = @[ @NO, @YES ];
		NSArray *results = [[inputs.rac_signal not] array];

		NSArray *expected = @[ @YES, @NO ];
		expect(results).to.equal(expected);
	});
});

describe(@"-and", ^{
	it(@"should return YES if all YES values are sent", ^{
		NSArray *inputs = @[
			RACTuplePack(@YES, @NO, @YES),
			RACTuplePack(@NO, @NO, @NO),
			RACTuplePack(@YES, @YES, @YES),
		];
		
		NSArray *results = [[inputs.rac_signal and] array];

		NSArray *expected = @[ @NO, @NO, @YES ];
		expect(results).to.equal(expected);
	});
});

describe(@"-or", ^{
	it(@"should return YES for any YES values sent", ^{
		NSArray *inputs = @[
			RACTuplePack(@YES, @NO, @YES),
			RACTuplePack(@NO, @NO, @NO),
		];
		
		NSArray *results = [[inputs.rac_signal or] array];

		NSArray *expected = @[ @YES, @NO ];
		expect(results).to.equal(expected);
	});
});

describe(@"-array", ^{
	it(@"should return an array which contains NSNulls for nil values", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendNext:nil];
			[subscriber sendCompleted];
		}];

		NSArray *expected = @[ NSNull.null, @1, NSNull.null ];
		expect([signal array]).to.equal(expected);
	});

	it(@"should return nil upon error", ^{
		RACSignal *signal = [RACSignal error:RACSignalTestError];
		expect([signal array]).to.beNil();
	});

	it(@"should return nil upon error even if some nexts were sent", ^{
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendError:RACSignalTestError];
		}];
		
		expect([signal array]).to.beNil();
	});
});

describe(@"-shareWhileActive", ^{
	__block NSUInteger totalSubscriptions;
	__block NSUInteger activeSubscriptions;

	__block RACSubject *subject;
	__block RACSignal *signal;

	beforeEach(^{
		totalSubscriptions = 0;
		activeSubscriptions = 0;

		subject = [RACSubject subject];
		signal = [[RACSignal
			create:^(id<RACSubscriber> subscriber) {
				totalSubscriptions++;
				activeSubscriptions++;

				[subject subscribe:subscriber];
				[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
					activeSubscriptions--;
				}]];
			}]
			shareWhileActive];
	});

	it(@"should lazily subscribe to the underlying signal", ^{
		expect(totalSubscriptions).to.equal(0);

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(1);

		[subject sendCompleted];
		expect(completed).to.beTruthy();
		expect(activeSubscriptions).to.equal(0);
	});

	it(@"should have at most one subscription to the underlying signal", ^{
		[signal subscribe:nil];
		[signal subscribe:nil];
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(1);

		[subject sendCompleted];
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(0);

		[signal subscribe:nil];
		[signal subscribe:nil];
		expect(totalSubscriptions).to.equal(2);
		expect(activeSubscriptions).to.equal(1);

		[subject sendCompleted];
		expect(totalSubscriptions).to.equal(2);
		expect(activeSubscriptions).to.equal(0);
	});

	it(@"should replay already-sent values to new subscribers then share events", ^{
		NSMutableArray *firstValues = [NSMutableArray array];
		__block BOOL firstCompleted = NO;
		[signal subscribeNext:^(id x) {
			[firstValues addObject:x];
		} completed:^{
			firstCompleted = YES;
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		expect(firstValues).to.equal((@[ @1, @2 ]));
		expect(firstCompleted).to.beFalsy();

		NSMutableArray *secondValues = [NSMutableArray array];
		__block BOOL secondCompleted = NO;
		[signal subscribeNext:^(id x) {
			[secondValues addObject:x];
		} completed:^{
			secondCompleted = YES;
		}];

		expect(secondValues).to.equal((@[ @1, @2 ]));
		expect(secondCompleted).to.beFalsy();

		[subject sendNext:@3];
		expect(firstValues).to.equal((@[ @1, @2, @3 ]));
		expect(firstCompleted).to.beFalsy();
		expect(secondValues).to.equal(firstValues);
		expect(secondCompleted).to.beFalsy();

		[subject sendCompleted];
		expect(firstValues).to.equal((@[ @1, @2, @3 ]));
		expect(firstCompleted).to.beTruthy();
		expect(secondValues).to.equal(firstValues);
		expect(secondCompleted).to.beTruthy();
	});

	it(@"should dispose of the underlying subscription when all subscribers are disposed", ^{
		RACDisposable *firstDisposable = [signal subscribe:nil];
		RACDisposable *secondDisposable = [signal subscribe:nil];
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(1);

		[secondDisposable dispose];
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(1);

		[firstDisposable dispose];
		expect(totalSubscriptions).to.equal(1);
		expect(activeSubscriptions).to.equal(0);
	});
});

describe(@"-flatten:withPolicy:", ^{
	__block RACSubject *signals;
	__block NSMutableArray *values;

	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;

	__block BOOL subscribed1 = NO;
	__block BOOL subscribed2 = NO;
	__block BOOL subscribed3 = NO;
	__block BOOL disposed1 = NO;
	__block BOOL disposed2 = NO;
	__block BOOL disposed3 = NO;
	__block RACSignal *signal1;
	__block RACSignal *signal2;
	__block RACSignal *signal3;

	beforeEach(^{
		signals = [RACSubject subject];
		values = [NSMutableArray array];

		subscribed1 = NO;
		subscribed2 = NO;
		subscribed3 = NO;
		disposed1 = NO;
		disposed2 = NO;
		disposed3 = NO;

		subject1 = [RACSubject subject];
		signal1 = [[RACSignal
			defer:^{
				subscribed1 = YES;
				return subject1;
			}]
			doDisposed:^{
				disposed1 = YES;
			}];

		subject2 = [RACSubject subject];
		signal2 = [[RACSignal
			defer:^{
				subscribed2 = YES;
				return subject2;
			}]
			doDisposed:^{
				disposed2 = YES;
			}];

		subject3 = [RACSubject subject];
		signal3 = [[RACSignal
			defer:^{
				subscribed3 = YES;
				return subject3;
			}]
			doDisposed:^{
				disposed3 = YES;
			}];
	});

	describe(@"queue policy", ^{
		it(@"should wait until a slot is available to merge new signals", ^{
			[[signals flatten:2 withPolicy:RACSignalFlattenPolicyQueue] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribed1).to.beFalsy();
			expect(subscribed2).to.beFalsy();
			expect(subscribed3).to.beFalsy();

			[signals sendNext:signal1];
			expect(subscribed1).to.beTruthy();

			[signals sendNext:signal2];
			expect(subscribed2).to.beTruthy();

			[signals sendNext:signal3];
			expect(subscribed3).to.beFalsy();

			[subject1 sendNext:@1];
			[signals sendCompleted];
			[subject2 sendNext:@2];
			[subject1 sendNext:@3];

			expect(subscribed3).to.beFalsy();

			[subject1 sendCompleted];
			expect(subscribed3).to.beTruthy();

			[subject3 sendNext:@4];
			[subject2 sendNext:@5];

			expect(values).to.equal((@[ @1, @2, @3, @4, @5 ]));
		});

		it(@"should complete only after the source and all its signals have completed", ^{
			__block BOOL completed = NO;
			[[signals flatten:2 withPolicy:RACSignalFlattenPolicyQueue] subscribeCompleted:^{
				completed = YES;
			}];

			[signals sendNext:signal1];
			[subject1 sendCompleted];

			expect(completed).to.beFalsy();

			[signals sendNext:signal2];
			[signals sendNext:signal3];
			[signals sendCompleted];

			expect(completed).to.beFalsy();

			[subject2 sendCompleted];

			expect(completed).to.beFalsy();

			[subject3 sendCompleted];

			expect(completed).to.beTruthy();
		});
	});

	describe(@"dispose earliest policy", ^{
		it(@"should dispose of earlier signals when new ones are sent", ^{
			[[signals flatten:2 withPolicy:RACSignalFlattenPolicyDisposeEarliest] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribed1).to.beFalsy();
			expect(subscribed2).to.beFalsy();
			expect(subscribed3).to.beFalsy();

			[signals sendNext:signal1];
			expect(subscribed1).to.beTruthy();

			[subject1 sendNext:@1];

			[signals sendNext:signal2];
			expect(subscribed2).to.beTruthy();

			[signals sendNext:signal3];
			expect(subscribed3).to.beTruthy();
			expect(disposed1).to.beTruthy();
			expect(disposed2).to.beFalsy();
			expect(disposed3).to.beFalsy();

			[signals sendCompleted];

			expect(disposed1).to.beTruthy();
			expect(disposed2).to.beFalsy();
			expect(disposed3).to.beFalsy();
			
			[subject2 sendNext:@2];
			[subject3 sendNext:@3];

			expect(disposed1).to.beTruthy();
			expect(disposed2).to.beFalsy();
			expect(disposed3).to.beFalsy();

			expect(values).to.equal((@[ @1, @2, @3 ]));
		});
	});

	describe(@"dispose latest policy", ^{
		it(@"should dispose of later signals when new ones are sent", ^{
			[[signals flatten:2 withPolicy:RACSignalFlattenPolicyDisposeLatest] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribed1).to.beFalsy();
			expect(subscribed2).to.beFalsy();
			expect(subscribed3).to.beFalsy();

			[signals sendNext:signal1];
			expect(subscribed1).to.beTruthy();

			[signals sendNext:signal2];
			expect(subscribed2).to.beTruthy();

			[subject2 sendNext:@1];

			[signals sendNext:signal3];
			expect(subscribed3).to.beTruthy();
			expect(disposed1).to.beFalsy();
			expect(disposed2).to.beTruthy();
			expect(disposed3).to.beFalsy();

			[signals sendCompleted];

			expect(disposed1).to.beFalsy();
			expect(disposed2).to.beTruthy();
			expect(disposed3).to.beFalsy();
			
			[subject1 sendNext:@2];
			[subject3 sendNext:@3];

			expect(disposed1).to.beFalsy();
			expect(disposed2).to.beTruthy();
			expect(disposed3).to.beFalsy();

			expect(values).to.equal((@[ @1, @2, @3 ]));
		});
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;

		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [subject flatten:1 withPolicy:RACSignalFlattenPolicyQueue];
			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribe:nil];
			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});

	it(@"should not crash when disposing while subscribing", ^{
		RACDisposable *disposable = [[signals flatten:1 withPolicy:RACSignalFlattenPolicyQueue] subscribe:nil];

		[signals sendNext:[RACSignal create:^(id<RACSubscriber> subscriber) {
			[disposable dispose];
			[subscriber sendCompleted];
		}]];

		[signals sendCompleted];
	});
});

SpecEnd
