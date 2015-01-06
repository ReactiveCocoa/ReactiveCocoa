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
#import "RACDisposable.h"
#import "RACSignal+Operations.h"
#import "RACScheduler.h"
#import "RACSubject.h"

@interface TestObject : NSObject
@property(nonatomic) int testInt;
@property(strong, nonatomic) NSString *testString;
@property(strong, nonatomic) TestObject *childObject;
@end

@implementation TestObject
@end

QuickSpecBegin(RACKVOProxySpec)

qck_describe(@"racproxyobserve", ^{
	__block TestObject *testObject;

	qck_beforeEach(^{
		testObject = [[TestObject alloc] init];
	});

	qck_afterEach(^{
		testObject = nil;
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

			expect(@(observedValue1)).toEventually(equal(@(testObject.testInt)));
			expect(@(observedValue2)).toEventually(equal(@(testObject.testInt)));
		});

		qck_it(@"can remove individual observation", ^{
			__block int observedValue1 = 0;
			__block int observedValue2 = 0;
			RACDisposable *disposable1 = [RACObserve(testObject, testInt)
										  subscribeNext:^(NSNumber *wrappedInt) {
											  observedValue1 = wrappedInt.intValue;
										  }];

			[RACObserve(testObject, testInt)
			 subscribeNext:^(NSNumber *wrappedInt) {
				 observedValue2 = wrappedInt.intValue;
			 }];

			testObject.testInt = 2;

			expect(@(observedValue1)).toEventually(equal(@(testObject.testInt)));
			expect(@(observedValue2)).toEventually(equal(@(testObject.testInt)));

			[disposable1 dispose];

			testObject.testInt = 3;

			expect(@(observedValue1)).toEventuallyNot(equal(@(testObject.testInt)));
			expect(@(observedValue2)).toEventually(equal(@(testObject.testInt)));
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

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				testObject.testInt = 2;
			});

			expect(@(observedValue)).toEventually(equal(@(testObject.testInt)));
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

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				testObject.testInt = 2;
			});

			expect(@(observedValue)).toEventually(equal(@(testObject.testInt)));
		});

		qck_it(@"async disposal of target", ^{
			__block int observedValue;
			[[RACObserve(testObject, testInt)
				deliverOn:RACScheduler.mainThreadScheduler]
				subscribeNext:^(NSNumber *wrappedInt) {
					observedValue = wrappedInt.intValue;
				}];

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				testObject.testInt = 2;
				testObject = nil;
			});

			expect(@(observedValue)).toEventually(equal(@2));
		});
	});

	qck_describe(@"stress", ^{
		static const int numIterations = 5000;

		qck_it(@"async disposal of observer reactivecocoa/1122", ^{
			__block int observedValue;
			__block RACDisposable *dispose;

			for (int i=0; i< numIterations; ++i) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[dispose dispose];
					dispose = nil;

					dispose = [RACObserve(testObject, testInt) subscribeNext:^(NSNumber *wrappedInt) {
						observedValue = wrappedInt.intValue;
					}];

					dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
						testObject.testInt++;
					});
				});
			}
		});

		qck_it(@"async disposal of signal with in-flight changes", ^{
			RACSubject *teardown = [RACSubject subject];

			RACSignal *isEvenSignal = [RACSignal defer:^{
				return [RACObserve(testObject, testInt)
						map:^id(NSNumber *wrappedInt) {
							return @((wrappedInt.intValue % 2) == 0);
						}];
			}];

			__block BOOL completed = NO;
			[[[isEvenSignal
				deliverOn:RACScheduler.mainThreadScheduler]
				takeUntil:teardown]
				subscribeCompleted:^{
					completed = YES;
				}];

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				for (int i=0; i<numIterations; ++i) {
					testObject.testInt = rand();
				}

				[teardown sendNext:nil];
			});

			expect(@(completed)).toEventually(beTruthy());
		});
	});
});

QuickSpecEnd
