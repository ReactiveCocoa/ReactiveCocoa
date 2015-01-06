//
//  NSObjectRACPropertySubscribingExamples.m
//  ReactiveCocoa
//
//  Created by Josh Vera on 4/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

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

QuickConfigurationBegin(NSObjectRACPropertySubscribingExamples)

+ (void)configure:(Configuration *)configuration {
	sharedExamples(RACPropertySubscribingExamples, ^(QCKDSLSharedExampleContext exampleContext) {
		__block RACSignal *(^signalBlock)(RACTestObject *object, NSString *keyPath, id observer);

		qck_beforeEach(^{
			signalBlock = exampleContext()[RACPropertySubscribingExamplesSetupBlock];
		});

		qck_it(@"should send the current value once on subscription", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
			NSMutableArray *values = [NSMutableArray array];

			object.objectValue = @0;
			[signal subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(values).to(equal((@[ @0 ])));
		});

		qck_it(@"should send the new value when it changes", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
			NSMutableArray *values = [NSMutableArray array];

			object.objectValue = @0;
			[signal subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(values).to(equal((@[ @0 ])));

			object.objectValue = @1;
			expect(values).to(equal((@[ @0, @1 ])));

		});

		qck_it(@"should stop observing when disposed", ^{
			RACTestObject *object = [[RACTestObject alloc] init];
			RACSignal *signal = signalBlock(object, @keypath(object, objectValue), self);
			NSMutableArray *values = [NSMutableArray array];

			object.objectValue = @0;
			RACDisposable *disposable = [signal subscribeNext:^(id x) {
				[values addObject:x];
			}];

			object.objectValue = @1;
			NSArray *expected = @[ @0, @1 ];
			expect(values).to(equal(expected));

			[disposable dispose];
			object.objectValue = @2;
			expect(values).to(equal(expected));
		});

		qck_it(@"shouldn't send any more values after the observer is gone", ^{
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

			expect(@(observerDealloced)).to(beTruthy());

			NSArray *expected = @[ @1 ];
			expect(values).to(equal(expected));

			object.objectValue = @2;
			expect(values).to(equal(expected));
		});

		qck_it(@"shouldn't keep either object alive unnaturally long", ^{
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

			expect(@(objectDealloced)).to(beTruthy());
			expect(@(scopeObjectDealloced)).to(beTruthy());
		});

		qck_it(@"shouldn't keep the signal alive past the lifetime of the object", ^{
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

			expect(@(signalDealloced)).toEventually(beTruthy());
			expect(@(objectDealloced)).to(beTruthy());
		});

		qck_it(@"shouldn't crash when the value is changed on a different queue", ^{
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

			expect(value).toEventually(equal(@1));
		});

		qck_describe(@"mutating collections", ^{
			__block RACTestObject *object;
			__block NSMutableOrderedSet *lastValue;
			__block NSMutableOrderedSet *proxySet;

			qck_beforeEach(^{
				object = [[RACTestObject alloc] init];
				object.objectValue = [NSMutableOrderedSet orderedSetWithObject:@1];

				NSString *keyPath = @keypath(object, objectValue);

				[signalBlock(object, keyPath, self) subscribeNext:^(NSMutableOrderedSet *x) {
					lastValue = x;
				}];

				proxySet = [object mutableOrderedSetValueForKey:keyPath];
			});

			qck_it(@"sends the newest object when inserting values into an observed object", ^{
				NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @1, @2, nil];

				[proxySet addObject:@2];
				expect(lastValue).to(equal(expected));
			});

			qck_it(@"sends the newest object when removing values in an observed object", ^{
				NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSet];

				[proxySet removeAllObjects];
				expect(lastValue).to(equal(expected));
			});

			qck_it(@"sends the newest object when replacing values in an observed object", ^{
				NSMutableOrderedSet *expected = [NSMutableOrderedSet orderedSetWithObjects: @2, nil];

				[proxySet replaceObjectAtIndex:0 withObject:@2];
				expect(lastValue).to(equal(expected));
			});
		});
	});
}

QuickConfigurationEnd
