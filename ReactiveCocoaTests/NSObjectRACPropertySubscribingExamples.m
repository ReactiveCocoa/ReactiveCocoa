//
//  NSObjectRACPropertySubscribingExamples.m
//  ReactiveCocoa
//
//  Created by Josh Vera on 4/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"
#import "NSObjectRACPropertySubscribingExamples.h"

#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"

NSString * const RACPropertySubscribingExamples = @"RACPropertySubscribingExamples";
NSString * const RACPropertySubscribingExamplesSetupBlock = @"RACPropertySubscribingExamplesSetupBlock";

SharedExamplesBegin(NSObjectRACPropertySubscribingExamples)

sharedExamples(RACPropertySubscribingExamples, ^(NSDictionary *data) {
	__block RACSignal *(^signalBlock)(RACTestObject *object, NSString *keyPath, id observer);

	before(^{
		signalBlock = data[RACPropertySubscribingExamplesSetupBlock];
	});

	it(@"should send the current value once on subscription", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
		NSMutableArray *values = [NSMutableArray array];

		object.objectValue = @0;
		[signal subscribeNext:^(id x) {
			[values addObject:x];
		}];

		expect(values).to.equal((@[ @0 ]));
	});

	it(@"should send the new value when it changes", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
		NSMutableArray *values = [NSMutableArray array];

		object.objectValue = @0;
		[signal subscribeNext:^(id x) {
			[values addObject:x];
		}];

		expect(values).to.equal((@[ @0 ]));

		object.objectValue = @1;
		expect(values).to.equal((@[ @0, @1 ]));

	});

	it(@"should stop observing when disposed", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
		NSMutableArray *values = [NSMutableArray array];

		object.objectValue = @0;
		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[values addObject:x];
		}];

		object.objectValue = @1;
		NSArray *expected = @[ @0, @1 ];
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
			[observer.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				observerDealloced = YES;
			}]];

			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), observer);
			object.objectValue = @1;
			[signal subscribeNext:^(id x) {
				[values addObject:x];
			}];
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
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				objectDealloced = YES;
			}]];
			RACTestObject *scopeObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[scopeObject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
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
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				objectDealloced = YES;
			}]];

			RACSignal *signal = [signalBlock(object, @keypath(object, objectValue), self) map:^(id value) {
				return value;
			}];

			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDealloced = YES;
			}]];

			[signal subscribeNext:^(id _) {

			}];
		}

		expect(signalDealloced).will.beTruthy();
		expect(objectDealloced).to.beTruthy();
	});

	it(@"should not resurrect a deallocated object upon subscription", ^{
		dispatch_queue_t queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT);
		@onExit {
			dispatch_release(queue);
		};

		dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));

		// Fuzz out race conditions.
		for (unsigned i = 0; i < 100; i++) {
			dispatch_suspend(queue);

			__block CFTypeRef object;
			__block BOOL deallocated;

			RACSignal *signal;

			@autoreleasepool {
				RACTestObject *testObject = [[RACTestObject alloc] init];
				[testObject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				signal = signalBlock(testObject, @keypath(testObject, objectValue), nil);
				object = CFBridgingRetain(testObject);
			}

			dispatch_block_t testSubscription = ^{
				RACDisposable *disposable = [signal subscribeCompleted:^{}];
				expect(disposable).notTo.beNil();
			};

			unsigned beforeCount = arc4random_uniform(20);
			for (unsigned j = 0; j < beforeCount; j++) {
				dispatch_async(queue, testSubscription);
			}

			dispatch_async(queue, ^{
				CFRelease(object);

				// expect() is a bit finicky on background threads.
				XCTAssertTrue(deallocated, @"Object did not deallocate after being released");
			});

			unsigned afterCount = arc4random_uniform(20);
			for (unsigned j = 0; j < afterCount; j++) {
				dispatch_async(queue, testSubscription);
			}

			dispatch_barrier_async(queue, testSubscription);

			// Start everything and wait for it all to complete.
			dispatch_resume(queue);

			expect(deallocated).will.beTruthy();
			dispatch_barrier_sync(queue, ^{});
		}
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

	describe(@"mutating collections", ^{
		__block RACTestObject *object;
		__block NSMutableOrderedSet *lastValue;
		__block NSMutableOrderedSet *proxySet;

		before(^{
			object = [[RACTestObject alloc] init];
			object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

			NSString *keyPath = @keypath(object, objectValue);

			[signalBlock(object, keyPath, self) subscribeNext:^(NSMutableOrderedSet *x) {
				lastValue = x;
			}];

			proxySet = [object mutableOrderedSetValueForKey:keyPath];
		});

		it(@"sends the newest object when inserting values into an observed object", ^{
			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @1, @2, nil];

			[proxySet addObject:@2];
			expect(lastValue).to.equal(expected);
		});

		it(@"sends the newest object when removing values in an observed object", ^{
			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSet];

			[proxySet removeAllObjects];
			expect(lastValue).to.equal(expected);
		});

		it(@"sends the newest object when replacing values in an observed object", ^{
			NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @2, nil];

			[proxySet replaceObjectAtIndex:0 withObject:@2];
			expect(lastValue).to.equal(expected);
		});
	});

});

SharedExamplesEnd
