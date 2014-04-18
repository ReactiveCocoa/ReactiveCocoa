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
#import "RACCompoundDisposable.h"
#import "RACInsertionMutation.h"
#import "RACMinusMutation.h"
#import "RACMoveMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSettingMutation.h"
#import "RACSignal+Operations.h"
#import "RACUnionMutation.h"
#import "RACUnit.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_valuesForKeyPath:", ^{
	id (^setupBlock)(id, id) = ^(RACTestObject *object, NSString *keyPath) {
		return [object rac_valuesForKeyPath:keyPath];
	};

	itShouldBehaveLike(RACPropertySubscribingExamples, ^{
		return @{ RACPropertySubscribingExamplesSetupBlock: setupBlock };
	});

});

describe(@"-rac_valuesAndChangesForKeyPath:options:", ^{
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

describe(@"-rac_valuesAndCollectionMutationsForKeyPath:", ^{
	__block RACTestObject *object;
	__block RACDisposable *disposable;

	__block id<RACOrderedCollectionMutation> arrayMutation;
	__block id<RACCollectionMutation> setMutation;

	__block void (^mutateArray)(NSKeyValueChange, NSIndexSet *, dispatch_block_t);
	__block void (^mutateSet)(NSKeyValueSetMutationKind, NSSet *, dispatch_block_t);

	beforeEach(^{
		object = [[RACTestObject alloc] init];

		NSArray *values = @[ @"foo", @"bar", @"fuzz", @"buzz" ];
		object.arrayValue = [NSMutableArray arrayWithArray:values];
		object.setValue = [NSMutableSet setWithArray:values];

		mutateArray = ^(NSKeyValueChange change, NSIndexSet *indexes, dispatch_block_t mutationBlock) {
			[object willChange:change valuesAtIndexes:indexes forKey:@keypath(object.arrayValue)];
			mutationBlock();
			[object didChange:change valuesAtIndexes:indexes forKey:@keypath(object.arrayValue)];
		};

		mutateSet = ^(NSKeyValueSetMutationKind change, NSSet *objects, dispatch_block_t mutationBlock) {
			[object willChangeValueForKey:@keypath(object.setValue) withSetMutation:change usingObjects:objects];
			mutationBlock();
			[object didChangeValueForKey:@keypath(object.setValue) withSetMutation:change usingObjects:objects];
		};
		
		setMutation = nil;
		arrayMutation = nil;

		RACDisposable *setDisposable = [[[[object
			rac_valuesAndCollectionMutationsForKeyPath:@keypath(object.setValue)]
			skip:1]
			reduceEach:^(NSSet *newValue, id mutation) {
				expect(object.setValue).to.equal(newValue);
				return mutation;
			}]
			subscribeNext:^(id mutation) {
				expect(mutation).notTo.beNil();
				setMutation = mutation;
			}];

		RACDisposable *arrayDisposable = [[[[object
			rac_valuesAndCollectionMutationsForKeyPath:@keypath(object.arrayValue)]
			skip:1]
			reduceEach:^(NSArray *newValue, id mutation) {
				expect(object.arrayValue).to.equal(newValue);
				return mutation;
			}]
			subscribeNext:^(id mutation) {
				expect(mutation).notTo.beNil();
				arrayMutation = mutation;
			}];

		expect(setDisposable).notTo.beNil();
		expect(arrayDisposable).notTo.beNil();

		disposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ setDisposable, arrayDisposable ]];
	});

	afterEach(^{
		object = nil;

		[disposable dispose];
		disposable = nil;
	});

	describe(@"setting the property", ^{
		it(@"should send RACSettingMutation for an unordered collection", ^{
			object.setValue = [NSMutableSet setWithObject:RACUnit.defaultUnit];

			id expectedMutation = [[RACSettingMutation alloc] initWithObjects:@[ RACUnit.defaultUnit ]];
			expect(setMutation).to.equal(expectedMutation);
		});

		it(@"should send RACSettingMutation for an ordered collection", ^{
			object.arrayValue = [NSMutableArray arrayWithObject:RACUnit.defaultUnit];

			id expectedMutation = [[RACSettingMutation alloc] initWithObjects:@[ RACUnit.defaultUnit ]];
			expect(arrayMutation).to.equal(expectedMutation);
		});

		it(@"should send RACSettingMutation for an ordered collection", ^{
			object.arrayValue = nil;

			id expectedMutation = [[RACSettingMutation alloc] initWithObjects:@[]];
			expect(arrayMutation).to.equal(expectedMutation);
		});

		it(@"should not send RACSettingMutation for an ordered collection", ^{
			expect(^{ object.arrayValue = (id)NSNull.null; }).to.raiseAny();
		});
	});

	describe(@"inserting", ^{
		it(@"should send RACUnionMutation for an unordered collection", ^{
			mutateSet(NSKeyValueUnionSetMutation, [NSSet setWithObject:RACUnit.defaultUnit], ^{
				[object.setValue addObject:RACUnit.defaultUnit];
			});

			id expectedMutation = [[RACUnionMutation alloc] initWithObjects:@[ RACUnit.defaultUnit ]];
			expect(setMutation).to.equal(expectedMutation);
		});

		it(@"should send RACInsertionMutation for an ordered collection", ^{
			NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:1];

			mutateArray(NSKeyValueChangeInsertion, indexes, ^{
				[object.arrayValue insertObject:RACUnit.defaultUnit atIndex:1];
			});

			id expectedMutation = [[RACInsertionMutation alloc] initWithObjects:@[ RACUnit.defaultUnit ] indexes:[NSIndexSet indexSetWithIndex:1]];
			expect(arrayMutation).to.equal(expectedMutation);
		});
	});

	describe(@"removing", ^{
		it(@"should send RACMinusMutation for an unordered collection", ^{
			mutateSet(NSKeyValueMinusSetMutation, [NSSet setWithObject:@"foo"], ^{
				[object.setValue removeObject:@"foo"];
			});

			id expectedMutation = [[RACMinusMutation alloc] initWithObjects:@[ @"foo" ]];
			expect(setMutation).to.equal(expectedMutation);
		});

		it(@"should send RACRemovalMutation for an ordered collection", ^{
			NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:1];

			mutateArray(NSKeyValueChangeRemoval, indexes, ^{
				[object.arrayValue removeObjectAtIndex:1];
			});

			id expectedMutation = [[RACRemovalMutation alloc] initWithObjects:@[ @"bar" ] indexes:[NSIndexSet indexSetWithIndex:1]];
			expect(arrayMutation).to.equal(expectedMutation);
		});
	});

	describe(@"replacement", ^{
		it(@"should send RACSettingMutation for an unordered collection", ^{
			NSSet *newValues = [NSSet setWithObjects:@"foo", @"fizz", nil];

			mutateSet(NSKeyValueSetSetMutation, newValues, ^{
				[object.setValue setSet:newValues];
			});

			id expectedMutation = [[RACSettingMutation alloc] initWithObjects:newValues.allObjects];
			expect(setMutation).to.equal(expectedMutation);
		});

		it(@"should send RACReplacementMutation for an ordered collection", ^{
			NSIndexSet *indexes = [NSIndexSet indexSetWithIndex:1];

			mutateArray(NSKeyValueChangeReplacement, indexes, ^{
				[object.arrayValue replaceObjectAtIndex:1 withObject:RACUnit.defaultUnit];
			});

			id expectedMutation = [[RACReplacementMutation alloc] initWithRemovedObjects:@[ @"bar" ] addedObjects:@[ RACUnit.defaultUnit ] indexes:[NSIndexSet indexSetWithIndex:1]];
			expect(arrayMutation).to.equal(expectedMutation);
		});
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
