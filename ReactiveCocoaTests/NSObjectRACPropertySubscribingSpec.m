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
#import "RACSignal.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_valuesForKeyPath:observer:", ^{
	id (^setupBlock)(id, id, id) = ^(RACTestObject *object, NSString *keyPath, id observer) {
		return [object rac_valuesForKeyPath:keyPath observer:observer];
	};

	itShouldBehaveLike(RACPropertySubscribingExamples, ^{
		return @{ RACPropertySubscribingExamplesSetupBlock: setupBlock };
	});

});

describe(@"+rac_signalWithChangesFor:keyPath:options:observer:", ^{
	describe(@"KVO options argument", ^{
		__block RACTestObject *object;
		__block id actual;
		__block RACSignal *(^objectValueSignal)(NSKeyValueObservingOptions);

		before(^{
			object = [[RACTestObject alloc] init];

			objectValueSignal = ^(NSKeyValueObservingOptions options) {
				return [[object rac_valuesAndChangesForKeyPath:@keypath(object, objectValue) options:options observer:self] reduceEach:^(id value, NSDictionary *change) {
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

describe(@"-rac_valuesAndChangesForKeyPath:options:observer:", ^{
	it(@"should complete immediately if the receiver or observer have deallocated", ^{
		RACSignal *signal;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			RACTestObject *observer __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			signal = [object rac_valuesAndChangesForKeyPath:@keypath(object, stringValue) options:0 observer:observer];
		}

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});
});

SpecEnd
