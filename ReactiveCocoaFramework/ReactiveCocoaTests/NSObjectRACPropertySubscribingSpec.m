//
//  NSObjectRACPropertySubscribingSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACTestObject.h"
#import "RACSignal.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_addDeallocDisposable:", ^{
	it(@"should dispose of the disposable when it is dealloc'd", ^{
		__block BOOL wasDisposed = NO;
		@autoreleasepool {
			NSObject *object __attribute__((objc_precise_lifetime)) = [[NSObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];

			expect(wasDisposed).to.beFalsy();
		}

		expect(wasDisposed).to.beTruthy();
	});
});

sharedExamples(@"RACPropertySubscribingExamples", ^(NSDictionary *data) {
	__block RACSignal *(^signalBlock)(RACTestObject *object, NSString *keyPath, id observer);

	before(^{
		signalBlock = data[@"signal"];
	});

	it(@"should stop observing when disposed", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
		NSMutableArray *values = [NSMutableArray array];
		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[values addObject:x];
		}];

		object.objectValue = @1;
		NSArray *expected = @[ @1 ];
		expect(values).to.equal(expected);

		[disposable dispose];
		object.objectValue = @2;
		expect(values).to.equal(expected);
	});

	it(@"shouldn't send any more values after the observer is gone", ^{
		__block BOOL observerDealloced = NO;
		RACTestObject *object = [[RACTestObject alloc] init];
		NSMutableArray *values = [NSMutableArray array];
		@autoreleasepool {
			RACTestObject *observer __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[observer rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				observerDealloced = YES;
			}]];

			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), observer);
			[signal subscribeNext:^(id x) {
				[values addObject:x];
			}];

			object.objectValue = @1;
		}

		expect(observerDealloced).to.beTruthy();

		NSArray *expected = @[ @1 ];
		expect(values).to.equal(expected);

		object.objectValue = @2;
		expect(values).to.equal(expected);
	});

	it(@"shouldn't keep either object alive unnaturally long", ^{
		__block BOOL objectDealloced = NO;
		__block BOOL scopeObjectDealloced = NO;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				objectDealloced = YES;
			}]];
			RACTestObject *scopeObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[scopeObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				scopeObjectDealloced = YES;
			}]];
			
			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), scopeObject);

			[signal subscribeNext:^(id _) {

			}];
		}

		expect(objectDealloced).to.beTruthy();
		expect(scopeObjectDealloced).to.beTruthy();
	});

	it(@"shouldn't keep the signal alive past the lifetime of the object", ^{
		__block BOOL objectDealloced = NO;
		__block BOOL signalDealloced = NO;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				objectDealloced = YES;
			}]];

			RACSignal *signal = [signalBlock(object, @keypath(object, objectValue), self) map:^(id value) {
				return value;
			}];

			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				signalDealloced = YES;
			}]];

			[signal subscribeNext:^(id _) {

			}];
		}

		expect(signalDealloced).will.beTruthy();
		expect(objectDealloced).to.beTruthy();
	});

	it(@"shouldn't crash when the value is changed on a different queue", ^{
		__block id value;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];

			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);

			[signal subscribeNext:^(id x) {
				value = x;
			}];

			NSOperationQueue *queue = [[NSOperationQueue alloc] init];
			[queue addOperationWithBlock:^{
				object.objectValue = @1;
			}];

			[queue waitUntilAllOperationsAreFinished];
		}

		expect(value).will.equal(@1);
	});

	it(@"sends an array when removing values from an observed value", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block NSMutableArray *values = [NSMutableArray new];

		object.objectValue = [@[ @1 ] mutableCopy];

		RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
		[signal subscribeNext:^(NSArray *_) {
			[values addObject:_];
		}];

		NSMutableArray *mutableArray = [object mutableArrayValueForKey:@"objectValue"];
		[mutableArray removeObject:object.objectValue];

		NSArray *expected = @[ ];
		expect(values).will.equal(expected);
	});

});

describe(@"+rac_signalFor:keyPath:observer:", ^{
	itShouldBehaveLike(@"RACPropertySubscribingExamples", @{
		@"signal": ^(RACTestObject *object, NSString *keyPath, id observer) {
			return [object.class rac_signalFor:object keyPath:keyPath observer:observer];
		}
	});

	describe(@"KVO options argument", ^{
		it(@"sends the newest set when inserting values into an observed value", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values;

			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			RACSignal *signal = [object.class rac_signalFor:object keyPath:@keypath(object, objectValue) observer:self];
			[signal subscribeNext:^(NSMutableOrderedSet *_) {
				values = _;
			}];

			NSMutableOrderedSet *mutableSet = [object mutableOrderedSetValueForKey:@"objectValue"];
			[mutableSet addObject:@2];

			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @1, @2, nil];
			expect(values).will.equal(expected);
		});

		it(@"sends the newest set when removing values in an observed value", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values;

			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			RACSignal *signal = [object.class rac_signalFor:object keyPath:@keypath(object, objectValue) observer:self];
			[signal subscribeNext:^(NSMutableOrderedSet *_) {
				values = _;
			}];

			NSMutableOrderedSet *mutableSet = [object mutableOrderedSetValueForKey:@"objectValue"];
			[mutableSet removeAllObjects];

			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSet];
			expect(values).will.equal(expected);
		});

		it(@"sends the newest set when replacing values in an observed value", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values;

			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			RACSignal *signal = [object.class rac_signalFor:object keyPath:@keypath(object, objectValue) observer:self];
			[signal subscribeNext:^(NSMutableOrderedSet *_) {
				values = _;
			}];

			NSMutableOrderedSet *mutableSet = [object mutableOrderedSetValueForKey:@"objectValue"];
			[mutableSet replaceObjectAtIndex:0 withObject:@2];

			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @2, nil];
			expect(values).will.equal(expected);
		});
	});
});

describe(@"+rac_signalWithChangesFor:keyPath:options:observer:", ^{
	itShouldBehaveLike(@"RACPropertySubscribingExamples", @{
		@"signal": ^(RACTestObject *object, NSString *keyPath, id observer) {
			return [[object.class
				rac_signalWithChangesFor:object keyPath:keyPath options:NSKeyValueObservingOptionNew observer:observer]
				map:^(NSDictionary *change) {
					return change[NSKeyValueChangeNewKey];
				}];
		}
	});

	describe(@"KVO options argument", ^{
		it(@"sends a KVO dictionary", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block id actualValue;

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@keypath(object, objectValue) options:0 observer:self];
			[signal subscribeNext:^(id x) {
				actualValue = x;
			}];

			object.objectValue = @1;
			
			expect(actualValue).will.beKindOf(NSDictionary.class);
		});

		it(@"sends a kind key by default", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSString *kindKey;

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@keypath(object, objectValue) options:0 observer:self];
			[signal subscribeNext:^(NSDictionary *_) {
				kindKey = _[NSKeyValueChangeKindKey];
			}];

			object.objectValue = @1;
			
			expect(kindKey).will.beTruthy();
		});

		it(@"sends the newest changes with NSKeyValueObservingOptionNew", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values = [NSMutableOrderedSet new];

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@"objectValue" options:NSKeyValueObservingOptionNew observer:self];
			[signal subscribeNext:^(NSNumber *value) {
				[values addObject:value];
			}];

			object.objectValue = @1;
			object.objectValue = @2;

			NSArray *expected = [NSOrderedSet orderedSetWithObjects:@1, @2, nil];
			expect([values valueForKeyPath:NSKeyValueChangeNewKey]).will.equal(expected);
		});

		it(@"sends an additional change value with NSKeyValueObservingOptionPrior", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values = [NSMutableOrderedSet new];
			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@"objectValue" options:NSKeyValueObservingOptionPrior observer:self];

			[signal subscribeNext:^(NSDictionary *change) {
				[values addObject:@([change[NSKeyValueChangeNotificationIsPriorKey] boolValue])];
			}];

			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			NSMutableOrderedSet *array = [object mutableOrderedSetValueForKey:@"objectValue"];
			[array addObject:@2];

			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects:@(YES), @(NO), nil];
			expect(values).will.equal(expected);
		});

		it(@"sends changes when adding, inserting or removing a value from an observed object", ^{

			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableOrderedSet *values = [NSMutableOrderedSet new];

			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@"objectValue" options:0 observer:self];

			[signal subscribeNext:^(NSDictionary *change) {
				[values addObject:@(change[NSKeyValueChangeIndexesKey] != nil)];
			}];

			NSMutableOrderedSet *array = [object mutableOrderedSetValueForKey:@"objectValue"];
			[array addObject:@2];

			[array replaceObjectAtIndex:0 withObject:@3];

			[array removeObject:@2];

			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects:@(YES), @(YES), @(YES), nil];
			expect(values).will.equal(expected);
		});

		it(@"also sends the previous value with NSKeyValueObservingOptionOld", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableArray *values = [NSMutableArray new];

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@keypath(object, objectValue) options:NSKeyValueObservingOptionOld observer:self];
			
			[signal subscribeNext:^(id x) {
				[values addObject:x[NSKeyValueChangeOldKey]];
			}];

			object.objectValue = @1;
			
			NSArray *expected = @[ NSNull.null ];
			expect(values).to.equal(expected);
		});

		it(@"also sends the initial value with NSKeyValueObservingOptionInitial", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			__block NSMutableArray *values = [NSMutableArray new];

			RACSignal *signal = [object.class rac_signalWithChangesFor:object keyPath:@keypath(object, objectValue) options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew observer:self];

			[signal subscribeNext:^(id x) {
				[values addObject:x[NSKeyValueChangeNewKey]];
			}];
			
			NSArray *expected = @[ NSNull.null ];
			expect(values).to.equal(expected);
		});
	});
});

SpecEnd
