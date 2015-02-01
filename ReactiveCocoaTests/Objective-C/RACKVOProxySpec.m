//
//  RACKVOProxySpec.m
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/24/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACKVOProxy.h"

#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACSerialDisposable.h"
#import "RACSignal+Operations.h"
#import "RACScheduler.h"
#import "RACSubject.h"

@interface TestObject : NSObject {
	volatile int _testInt;
}

@property (assign, atomic) int testInt;

@end

@implementation TestObject

- (int)testInt {
	return _testInt;
}

// Use manual KVO notifications to avoid any possible race conditions within the
// automatic KVO implementation.
- (void)setTestInt:(int)value {
	[self willChangeValueForKey:@keypath(self.testInt)];
	_testInt = value;
	[self didChangeValueForKey:@keypath(self.testInt)];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	return NO;
}

@end

QuickSpecBegin(RACKVOProxySpec)

qck_describe(@"RACKVOProxy", ^{
	__block TestObject *testObject;
	__block dispatch_queue_t concurrentQueue;

	qck_beforeEach(^{
		testObject = [[TestObject alloc] init];
		concurrentQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.concurrentQueue", DISPATCH_QUEUE_CONCURRENT);
	});

	qck_afterEach(^{
		dispatch_barrier_sync(concurrentQueue, ^{
			testObject = nil;
		});
	});

	qck_describe(@"basic", ^{
		qck_it(@"should handle multiple observations on the same value", ^{
			__block int observedValue1 = 0;
			__block int observedValue2 = 0;

			[[[RACObserve(testObject, testInt)
				skip:1]
				take:1]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue1 = wrappedInt.intValue;
				}];

			[[[RACObserve(testObject, testInt)
				skip:1]
				take:1]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue2 = wrappedInt.intValue;
				}];

			testObject.testInt = 2;

			expect(@(observedValue1)).toEventually(equal(@2));
			expect(@(observedValue2)).toEventually(equal(@2));
		});

		qck_it(@"can remove individual observation", ^{
			__block int observedValue1 = 0;
			__block int observedValue2 = 0;

			RACDisposable *disposable1 = [RACObserve(testObject, testInt) subscribeNext:^(NSNumber *wrappedInt) {
				observedValue1 = wrappedInt.intValue;
			}];

			[RACObserve(testObject, testInt) subscribeNext:^(NSNumber *wrappedInt) {
				observedValue2 = wrappedInt.intValue;
			}];

			testObject.testInt = 2;

			expect(@(observedValue1)).toEventually(equal(@2));
			expect(@(observedValue2)).toEventually(equal(@2));

			[disposable1 dispose];
			testObject.testInt = 3;

			expect(@(observedValue2)).toEventually(equal(@3));
			expect(@(observedValue1)).to(equal(@2));
		});
	});

	qck_describe(@"async", ^{
		qck_it(@"should handle changes being made on another queue", ^{
			__block int observedValue = 0;
			[[[RACObserve(testObject, testInt)
				skip:1]
				take:1]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue = wrappedInt.intValue;
				}];

			dispatch_async(concurrentQueue, ^{
				testObject.testInt = 2;
			});

			dispatch_barrier_sync(concurrentQueue, ^{});
			expect(@(observedValue)).toEventually(equal(@2));
		});

		qck_it(@"should handle changes being made on another queue using deliverOn", ^{
			__block int observedValue = 0;
			[[[[RACObserve(testObject, testInt)
				skip:1]
				take:1]
				deliverOn:[RACScheduler mainThreadScheduler]]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue = wrappedInt.intValue;
				}];

			dispatch_async(concurrentQueue, ^{
				testObject.testInt = 2;
			});

			dispatch_barrier_sync(concurrentQueue, ^{});
			expect(@(observedValue)).toEventually(equal(@2));
		});

		qck_it(@"async disposal of target", ^{
			__block int observedValue;
			[[RACObserve(testObject, testInt)
				deliverOn:RACScheduler.mainThreadScheduler]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue = wrappedInt.intValue;
				}];

			dispatch_async(concurrentQueue, ^{
				testObject.testInt = 2;
				testObject = nil;
			});

			dispatch_barrier_sync(concurrentQueue, ^{});
			expect(@(observedValue)).toEventually(equal(@2));
		});
	});

	qck_describe(@"stress", ^{
		static const size_t numIterations = 5000;

		__block dispatch_queue_t iterationQueue;

		beforeEach(^{
			iterationQueue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACKVOProxySpec.iterationQueue", DISPATCH_QUEUE_CONCURRENT);
		});

		// ReactiveCocoa/ReactiveCocoa#1122
		qck_it(@"async disposal of observer", ^{
			RACSerialDisposable *disposable = [[RACSerialDisposable alloc] init];

			dispatch_apply(numIterations, iterationQueue, ^(size_t index) {
				RACDisposable *newDisposable = [RACObserve(testObject, testInt) subscribeCompleted:^{}];
				[[disposable swapInDisposable:newDisposable] dispose];

				dispatch_async(concurrentQueue, ^{
					testObject.testInt = (int)index;
				});
			});

			dispatch_barrier_sync(iterationQueue, ^{
				[disposable dispose];
			});
		});

		qck_it(@"async disposal of signal with in-flight changes", ^{
			RACSubject *teardown = [RACSubject subject];

			RACSignal *isEvenSignal = [[[[RACObserve(testObject, testInt)
				map:^(NSNumber *wrappedInt) {
					return @((wrappedInt.intValue % 2) == 0);
				}]
				deliverOn:RACScheduler.mainThreadScheduler]
				takeUntil:teardown]
				replayLast];

			dispatch_apply(numIterations, iterationQueue, ^(size_t index) {
				testObject.testInt = (int)index;
			});

			dispatch_barrier_async(iterationQueue, ^{
				[teardown sendNext:nil];
			});

			expect(@([isEvenSignal asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
		});
	});
});

QuickSpecEnd
