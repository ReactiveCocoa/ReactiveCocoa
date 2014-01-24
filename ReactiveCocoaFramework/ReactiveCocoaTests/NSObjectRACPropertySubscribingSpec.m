//
//  NSObjectRACPropertySubscribingSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObjectRACPropertySubscribingExamples.h"
#import "RACTestObject.h"

#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_valuesForKeyPath:", ^{
	id (^setupBlock)(id, id) = ^(RACTestObject *object, NSString *keyPath) {
		return [object rac_valuesForKeyPath:keyPath];
	};

	itShouldBehaveLike(RACPropertySubscribingExamples, ^{
		return @{ RACPropertySubscribingExamplesSetupBlock: setupBlock };
	});

});

describe(@"+rac_signalWithChangesFor:keyPath:options:", ^{
	describe(@"KVO options argument", ^{
		__block RACTestObject *object;
		__block id actual;
		__block RACSignal *(^objectValueSignal)(NSKeyValueObservingOptions);

		before(^{
			object = [[RACTestObject alloc] init];

			objectValueSignal = ^(NSKeyValueObservingOptions options) {
				return [[object rac_valuesAndChangesForKeyPath:@keypath(object, objectValue) options:options] reduceEach:^(id value, NSDictionary *change) {
					return change;
				}];
			};
		});

		it(@"sends a KVO dictionary", ^{
			[objectValueSignal(0) subscribeNext:^(NSDictionary *x) {
				actual = x;
			}];

			object.objectValue = @1;

			expect(actual).to.beKindOf(NSDictionary.class);
		});

		it(@"sends a kind key by default", ^{
			[objectValueSignal(0) subscribeNext:^(NSDictionary *x) {
				actual = x[NSKeyValueChangeKindKey];
			}];

			object.objectValue = @1;

			expect(actual).notTo.beNil();
		});

		it(@"sends the newest changes with NSKeyValueObservingOptionNew", ^{
			[objectValueSignal(NSKeyValueObservingOptionNew) subscribeNext:^(NSDictionary *x) {
				actual = x[NSKeyValueChangeNewKey];
			}];

			object.objectValue = @1;
			expect(actual).to.equal(@1);

			object.objectValue = @2;
			expect(actual).to.equal(@2);
		});

		it(@"sends an additional change value with NSKeyValueObservingOptionPrior", ^{
			NSMutableArray *values = [NSMutableArray new];
			NSArray *expected = @[ @(YES), @(NO) ];

			[objectValueSignal(NSKeyValueObservingOptionPrior) subscribeNext:^(NSDictionary *x) {
				BOOL isPrior = [x[NSKeyValueChangeNotificationIsPriorKey] boolValue];
				[values addObject:@(isPrior)];
			}];

			object.objectValue = @[ @1 ];

			expect(values).to.equal(expected);
		});

		it(@"sends index changes when adding, inserting or removing a value from an observed object", ^{
			__block NSUInteger hasIndexesCount = 0;

			[objectValueSignal(0) subscribeNext:^(NSDictionary *x) {
				if (x[NSKeyValueChangeIndexesKey] != nil) {
					hasIndexesCount += 1;
				}
			}];

			object.objectValue = [NSMutableOrderedSet orderedSet];
			expect(hasIndexesCount).to.equal(0);

			NSMutableOrderedSet *objectValue = [object mutableOrderedSetValueForKey:@"objectValue"];

			[objectValue addObject:@1];
			expect(hasIndexesCount).to.equal(1);

			[objectValue replaceObjectAtIndex:0 withObject:@2];
			expect(hasIndexesCount).to.equal(2);

			[objectValue removeObject:@2];
			expect(hasIndexesCount).to.equal(3);
		});

		it(@"sends the previous value with NSKeyValueObservingOptionOld", ^{
			[objectValueSignal(NSKeyValueObservingOptionOld) subscribeNext:^(NSDictionary *x) {
				actual = x[NSKeyValueChangeOldKey];
			}];

			object.objectValue = @1;
			expect(actual).to.equal(NSNull.null);

			object.objectValue = @2;
			expect(actual).to.equal(@1);
		});

		it(@"sends the initial value with NSKeyValueObservingOptionInitial", ^{
			[objectValueSignal(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) subscribeNext:^(NSDictionary *x) {
				actual = x[NSKeyValueChangeNewKey];
			}];
			
			expect(actual).to.equal(NSNull.null);
		});
	});
});

describe(@"-rac_valuesAndChangesForKeyPath:options:", ^{
	it(@"should complete immediately if the receiver has deallocated", ^{
		RACSignal *signal;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			signal = [object rac_valuesAndChangesForKeyPath:@keypath(object, stringValue) options:0];
		}

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});
});

describe(@"RACObserve", ^{
	__block RACTestObject *testObject;

	beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should work with object properties", ^{
		NSArray *expected = @[ @"hello", @"world" ];
		testObject.objectValue = expected[0];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, objectValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.objectValue = expected[1];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should work with non-object properties", ^{
		NSArray *expected = @[ @42, @43 ];
		testObject.integerValue = [expected[0] integerValue];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, integerValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.integerValue = [expected[1] integerValue];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should read the initial value upon subscription", ^{
		testObject.objectValue = @"foo";

		RACSignal *signal = RACObserve(testObject, objectValue);
		testObject.objectValue = @"bar";

		expect([signal first]).to.equal(@"bar");
	});
});

SpecEnd
