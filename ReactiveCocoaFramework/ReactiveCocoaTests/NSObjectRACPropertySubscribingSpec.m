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
});

describe(@"+rac_signalFor:keyPath:onObject:", ^{
	itShouldBehaveLike(@"RACPropertySubscribingExamples", @{
		@"signal": ^(RACTestObject *object, NSString *keyPath, id observer) {
			return [object.class rac_signalFor:object keyPath:keyPath observer:observer];
		}
	});
});

SpecEnd
