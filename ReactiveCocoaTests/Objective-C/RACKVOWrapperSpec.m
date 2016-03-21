//
//  RACKVOWrapperSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "NSObject+RACKVOWrapper.h"

#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACTestObject.h"

@interface RACTestOperation : NSOperation
@end

// The name of the examples.
static NSString * const RACKVOWrapperExamples = @"RACKVOWrapperExamples";

// A block that returns an object to observe in the examples.
static NSString * const RACKVOWrapperExamplesTargetBlock = @"RACKVOWrapperExamplesTargetBlock";

// The key path to observe in the examples.
//
// The key path must have at least one weak property in it.
static NSString * const RACKVOWrapperExamplesKeyPath = @"RACKVOWrapperExamplesKeyPath";

// A block that changes the value of a weak property in the observed key path.
// The block is passed the object the example is observing and the new value the
// weak property should be changed to(
static NSString * const RACKVOWrapperExamplesChangeBlock = @"RACKVOWrapperExamplesChangeBlock";

// A block that returns a valid value for the weak property changed by
// RACKVOWrapperExamplesChangeBlock. The value must deallocate
// normally.
static NSString * const RACKVOWrapperExamplesValueBlock = @"RACKVOWrapperExamplesValueBlock";

// Whether RACKVOWrapperExamplesChangeBlock changes the value
// of the last key path component in the key path directly.
static NSString * const RACKVOWrapperExamplesChangesValueDirectly = @"RACKVOWrapperExamplesChangesValueDirectly";

// The name of the examples.
static NSString * const RACKVOWrapperCollectionExamples = @"RACKVOWrapperCollectionExamples";

// A block that returns an object to observe in the examples.
static NSString * const RACKVOWrapperCollectionExamplesTargetBlock = @"RACKVOWrapperCollectionExamplesTargetBlock";

// The key path to observe in the examples.
//
// Must identify a property of type NSOrderedSet.
static NSString * const RACKVOWrapperCollectionExamplesKeyPath = @"RACKVOWrapperCollectionExamplesKeyPath";

QuickConfigurationBegin(RACKVOWrapperExampleGroups)

+ (void)configure:(Configuration *)configuration {
	sharedExamples(RACKVOWrapperExamples, ^(QCKDSLSharedExampleContext exampleContext) {
		__block NSObject *target = nil;
		__block NSString *keyPath = nil;
		__block void (^changeBlock)(NSObject *, id) = nil;
		__block id (^valueBlock)(void) = nil;
		__block BOOL changesValueDirectly = NO;

		__block NSUInteger priorCallCount = 0;
		__block NSUInteger posteriorCallCount = 0;
		__block BOOL priorTriggeredByLastKeyPathComponent = NO;
		__block BOOL posteriorTriggeredByLastKeyPathComponent = NO;
		__block BOOL posteriorTriggeredByDeallocation = NO;
		__block void (^callbackBlock)(id, NSDictionary *, BOOL, BOOL) = nil;

		qck_beforeEach(^{
			NSObject * (^targetBlock)(void) = exampleContext()[RACKVOWrapperExamplesTargetBlock];
			target = targetBlock();
			keyPath = exampleContext()[RACKVOWrapperExamplesKeyPath];
			changeBlock = exampleContext()[RACKVOWrapperExamplesChangeBlock];
			valueBlock = exampleContext()[RACKVOWrapperExamplesValueBlock];
			changesValueDirectly = [exampleContext()[RACKVOWrapperExamplesChangesValueDirectly] boolValue];

			priorCallCount = 0;
			posteriorCallCount = 0;

			callbackBlock = [^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
					priorTriggeredByLastKeyPathComponent = affectedOnlyLastComponent;
					++priorCallCount;
					return;
				}
				posteriorTriggeredByLastKeyPathComponent = affectedOnlyLastComponent;
				posteriorTriggeredByDeallocation = causedByDealloc;
				++posteriorCallCount;
			} copy];
		});

		qck_afterEach(^{
			target = nil;
			keyPath = nil;
			changeBlock = nil;
			valueBlock = nil;
			changesValueDirectly = NO;

			callbackBlock = nil;
		});

		qck_it(@"should not call the callback block on add if called without NSKeyValueObservingOptionInitial", ^{
			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:nil block:callbackBlock];
			expect(@(priorCallCount)).to(equal(@0));
			expect(@(posteriorCallCount)).to(equal(@0));
		});

		qck_it(@"should call the callback block on add if called with NSKeyValueObservingOptionInitial", ^{
			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionInitial observer:nil block:callbackBlock];
			expect(@(priorCallCount)).to(equal(@0));
			expect(@(posteriorCallCount)).to(equal(@1));
		});

		qck_it(@"should call the callback block twice per change, once prior and once posterior", ^{
			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:nil block:callbackBlock];
			priorCallCount = 0;
			posteriorCallCount = 0;

			id value1 = valueBlock();
			changeBlock(target, value1);
			expect(@(priorCallCount)).to(equal(@1));
			expect(@(posteriorCallCount)).to(equal(@1));
			expect(@(priorTriggeredByLastKeyPathComponent)).to(equal(@(changesValueDirectly)));
			expect(@(posteriorTriggeredByLastKeyPathComponent)).to(equal(@(changesValueDirectly)));
			expect(@(posteriorTriggeredByDeallocation)).to(beFalsy());

			id value2 = valueBlock();
			changeBlock(target, value2);
			expect(@(priorCallCount)).to(equal(@2));
			expect(@(posteriorCallCount)).to(equal(@2));
			expect(@(priorTriggeredByLastKeyPathComponent)).to(equal(@(changesValueDirectly)));
			expect(@(posteriorTriggeredByLastKeyPathComponent)).to(equal(@(changesValueDirectly)));
			expect(@(posteriorTriggeredByDeallocation)).to(beFalsy());
		});

		qck_it(@"should call the callback block with NSKeyValueChangeNotificationIsPriorKey set before the value is changed, and not set after the value is changed", ^{
			__block BOOL priorCalled = NO;
			__block BOOL posteriorCalled = NO;
			__block id priorValue = nil;
			__block id posteriorValue = nil;

			id value1 = valueBlock();
			changeBlock(target, value1);
			id oldValue = [target valueForKeyPath:keyPath];

			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
					priorCalled = YES;
					priorValue = value;
					expect(@(posteriorCalled)).to(beFalsy());
					return;
				}
				posteriorCalled = YES;
				posteriorValue = value;
				expect(@(priorCalled)).to(beTruthy());
			}];

			id value2 = valueBlock();
			changeBlock(target, value2);
			id newValue = [target valueForKeyPath:keyPath];
			expect(@(priorCalled)).to(beTruthy());
			expect(priorValue).to(equal(oldValue));
			expect(@(posteriorCalled)).to(beTruthy());
			expect(posteriorValue).to(equal(newValue));
		});

		qck_it(@"should not call the callback block after it's been disposed", ^{
			RACDisposable *disposable = [target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:nil block:callbackBlock];
			priorCallCount = 0;
			posteriorCallCount = 0;

			[disposable dispose];
			expect(@(priorCallCount)).to(equal(@0));
			expect(@(posteriorCallCount)).to(equal(@0));

			id value = valueBlock();
			changeBlock(target, value);
			expect(@(priorCallCount)).to(equal(@0));
			expect(@(posteriorCallCount)).to(equal(@0));
		});

		qck_it(@"should call the callback block only once with NSKeyValueChangeNotificationIsPriorKey not set when the value is deallocated", ^{
			__block BOOL valueDidDealloc = NO;

			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionPrior observer:nil block:callbackBlock];

			@autoreleasepool {
				NSObject *value __attribute__((objc_precise_lifetime)) = valueBlock();
				[value.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					valueDidDealloc = YES;
				}]];

				changeBlock(target, value);
				priorCallCount = 0;
				posteriorCallCount = 0;
			}

			expect(@(valueDidDealloc)).to(beTruthy());
			expect(@(priorCallCount)).to(equal(@0));
			expect(@(posteriorCallCount)).to(equal(@1));
			expect(@(posteriorTriggeredByDeallocation)).to(beTruthy());
		});
	});

	qck_sharedExamples(RACKVOWrapperCollectionExamples, ^(QCKDSLSharedExampleContext exampleContext) {
		__block NSObject *target = nil;
		__block NSString *keyPath = nil;
		__block NSMutableOrderedSet *mutableKeyPathProxy = nil;
		__block void (^callbackBlock)(id, NSDictionary *, BOOL, BOOL) = nil;

		__block id priorValue = nil;
		__block id posteriorValue = nil;
		__block NSDictionary *priorChange = nil;
		__block NSDictionary *posteriorChange = nil;

		qck_beforeEach(^{
			NSObject * (^targetBlock)(void) = exampleContext()[RACKVOWrapperCollectionExamplesTargetBlock];
			target = targetBlock();
			keyPath = exampleContext()[RACKVOWrapperCollectionExamplesKeyPath];

			callbackBlock = [^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
					priorValue = value;
					priorChange = change;
					return;
				}
				posteriorValue = value;
				posteriorChange = change;
			} copy];

			[target setValue:[NSOrderedSet orderedSetWithObject:@0] forKeyPath:keyPath];
			[target rac_observeKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior observer:nil block:callbackBlock];
			mutableKeyPathProxy = [target mutableOrderedSetValueForKeyPath:keyPath];
		});

		qck_afterEach(^{
			target = nil;
			keyPath = nil;
			callbackBlock = nil;

			priorValue = nil;
			priorChange = nil;
			posteriorValue = nil;
			posteriorChange = nil;
		});

		qck_it(@"should support inserting elements into ordered collections", ^{
			[mutableKeyPathProxy insertObject:@1 atIndex:0];

			expect(priorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @0 ]]));
			expect(posteriorValue).to(equal([NSOrderedSet orderedSetWithArray:(@[ @1, @0 ])]));
			expect(priorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeInsertion)));
			expect(posteriorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeInsertion)));
			expect(priorChange[NSKeyValueChangeOldKey]).to(beNil());
			expect(posteriorChange[NSKeyValueChangeNewKey]).to(equal(@[ @1 ]));
			expect(priorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
			expect(posteriorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
		});

		qck_it(@"should support removing elements from ordered collections", ^{
			[mutableKeyPathProxy removeObjectAtIndex:0];

			expect(priorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @0 ]]));
			expect(posteriorValue).to(equal([NSOrderedSet orderedSetWithArray:@[]]));
			expect(priorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeRemoval)));
			expect(posteriorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeRemoval)));
			expect(priorChange[NSKeyValueChangeOldKey]).to(equal(@[ @0 ]));
			expect(posteriorChange[NSKeyValueChangeNewKey]).to(beNil());
			expect(priorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
			expect(posteriorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
		});

		qck_it(@"should support replacing elements in ordered collections", ^{
			[mutableKeyPathProxy replaceObjectAtIndex:0 withObject:@1];

			expect(priorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @0 ]]));
			expect(posteriorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @1 ]]));
			expect(priorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeReplacement)));
			expect(posteriorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeReplacement)));
			expect(priorChange[NSKeyValueChangeOldKey]).to(equal(@[ @0 ]));
			expect(posteriorChange[NSKeyValueChangeNewKey]).to(equal(@[ @1 ]));
			expect(priorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
			expect(posteriorChange[NSKeyValueChangeIndexesKey]).to(equal([NSIndexSet indexSetWithIndex:0]));
		});

		qck_it(@"should support adding elements to unordered collections", ^{
			[mutableKeyPathProxy unionOrderedSet:[NSOrderedSet orderedSetWithObject:@1]];

			expect(priorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @0 ]]));
			expect(posteriorValue).to(equal([NSOrderedSet orderedSetWithArray:(@[ @0, @1 ])]));
			expect(priorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeInsertion)));
			expect(posteriorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeInsertion)));
			expect(priorChange[NSKeyValueChangeOldKey]).to(beNil());
			expect(posteriorChange[NSKeyValueChangeNewKey]).to(equal(@[ @1 ]));
		});

		qck_it(@"should support removing elements from unordered collections", ^{
			[mutableKeyPathProxy minusOrderedSet:[NSOrderedSet orderedSetWithObject:@0]];

			expect(priorValue).to(equal([NSOrderedSet orderedSetWithArray:@[ @0 ]]));
			expect(posteriorValue).to(equal([NSOrderedSet orderedSetWithArray:@[]]));
			expect(priorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeRemoval)));
			expect(posteriorChange[NSKeyValueChangeKindKey]).to(equal(@(NSKeyValueChangeRemoval)));
			expect(priorChange[NSKeyValueChangeOldKey]).to(equal(@[ @0 ]));
			expect(posteriorChange[NSKeyValueChangeNewKey]).to(beNil());
		});
	});
}

QuickConfigurationEnd

QuickSpecBegin(RACKVOWrapperSpec)

qck_describe(@"-rac_observeKeyPath:options:observer:block:", ^{
	qck_describe(@"on simple keys", ^{
		NSObject * (^targetBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};

		void (^changeBlock)(RACTestObject *, id) = ^(RACTestObject *target, id value) {
			target.weakTestObjectValue = value;
		};

		id (^valueBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};

		qck_itBehavesLike(RACKVOWrapperExamples, ^{
			return @{
				RACKVOWrapperExamplesTargetBlock: targetBlock,
				RACKVOWrapperExamplesKeyPath: @keypath(RACTestObject.new, weakTestObjectValue),
				RACKVOWrapperExamplesChangeBlock: changeBlock,
				RACKVOWrapperExamplesValueBlock: valueBlock,
				RACKVOWrapperExamplesChangesValueDirectly: @YES
			};
		});

		qck_itBehavesLike(RACKVOWrapperCollectionExamples, ^{
			return @{
				RACKVOWrapperCollectionExamplesTargetBlock: targetBlock,
				RACKVOWrapperCollectionExamplesKeyPath: @keypath(RACTestObject.new, orderedSetValue)
			};
		});
	});

	qck_describe(@"on composite key paths'", ^{
		qck_describe(@"last key path components", ^{
			NSObject *(^targetBlock)(void) = ^{
				RACTestObject *object = [[RACTestObject alloc] init];
				object.strongTestObjectValue = [[RACTestObject alloc] init];
				return object;
			};

			void (^changeBlock)(RACTestObject *, id) = ^(RACTestObject *target, id value) {
				target.strongTestObjectValue.weakTestObjectValue = value;
			};

			id (^valueBlock)(void) = ^{
				return [[RACTestObject alloc] init];
			};

			qck_itBehavesLike(RACKVOWrapperExamples, ^{
				return @{
					RACKVOWrapperExamplesTargetBlock: targetBlock,
					RACKVOWrapperExamplesKeyPath: @keypath(RACTestObject.new, strongTestObjectValue.weakTestObjectValue),
					RACKVOWrapperExamplesChangeBlock: changeBlock,
					RACKVOWrapperExamplesValueBlock: valueBlock,
					RACKVOWrapperExamplesChangesValueDirectly: @YES
				};
			});

			qck_itBehavesLike(RACKVOWrapperCollectionExamples, ^{
				return @{
					RACKVOWrapperCollectionExamplesTargetBlock: targetBlock,
					RACKVOWrapperCollectionExamplesKeyPath: @keypath(RACTestObject.new, strongTestObjectValue.orderedSetValue)
				};
			});
		});

		qck_describe(@"intermediate key path components", ^{
			NSObject *(^targetBlock)(void) = ^{
				return [[RACTestObject alloc] init];
			};

			void (^changeBlock)(RACTestObject *, id) = ^(RACTestObject *target, id value) {
				target.weakTestObjectValue = value;
			};

			id (^valueBlock)(void) = ^{
				RACTestObject *object = [[RACTestObject alloc] init];
				object.strongTestObjectValue = [[RACTestObject alloc] init];
				return object;
			};

			qck_itBehavesLike(RACKVOWrapperExamples, ^{
				return @{
					RACKVOWrapperExamplesTargetBlock: targetBlock,
					RACKVOWrapperExamplesKeyPath: @keypath([[RACTestObject alloc] init], weakTestObjectValue.strongTestObjectValue),
					RACKVOWrapperExamplesChangeBlock: changeBlock,
					RACKVOWrapperExamplesValueBlock: valueBlock,
					RACKVOWrapperExamplesChangesValueDirectly: @NO
				};
			});
		});

		qck_it(@"should not notice deallocation of the object returned by a dynamic final property", ^{
			RACTestObject *object = [[RACTestObject alloc] init];

			__block id lastValue = nil;
			@autoreleasepool {
				[object rac_observeKeyPath:@keypath(object.dynamicObjectProperty) options:NSKeyValueObservingOptionInitial observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
					lastValue = value;
				}];

				expect(lastValue).to(beAKindOf(RACTestObject.class));
			}

			expect(lastValue).to(beAKindOf(RACTestObject.class));
		});

		qck_it(@"should not notice deallocation of the object returned by a dynamic intermediate property", ^{
			RACTestObject *object = [[RACTestObject alloc] init];

			__block id lastValue = nil;
			@autoreleasepool {
				[object rac_observeKeyPath:@keypath(object.dynamicObjectProperty.integerValue) options:NSKeyValueObservingOptionInitial observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
					lastValue = value;
				}];

				expect(lastValue).to(equal(@42));
			}

			expect(lastValue).to(equal(@42));
		});

		qck_it(@"should not notice deallocation of the object returned by a dynamic method", ^{
			RACTestObject *object = [[RACTestObject alloc] init];

			__block id lastValue = nil;
			@autoreleasepool {
				[object rac_observeKeyPath:@keypath(object.dynamicObjectMethod) options:NSKeyValueObservingOptionInitial observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
					lastValue = value;
				}];

				expect(lastValue).to(beAKindOf(RACTestObject.class));
			}

			expect(lastValue).to(beAKindOf(RACTestObject.class));
		});
	});

	qck_it(@"should not call the callback block when the value is the observer", ^{
		__block BOOL observerDisposed = NO;
		__block BOOL observerDeallocationTriggeredChange = NO;
		__block BOOL targetDisposed = NO;
		__block BOOL targetDeallocationTriggeredChange = NO;

		@autoreleasepool {
			RACTestObject *observer __attribute__((objc_precise_lifetime)) = [RACTestObject new];
			[observer.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				observerDisposed = YES;
			}]];

			RACTestObject *target __attribute__((objc_precise_lifetime)) = [RACTestObject new];
			[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				targetDisposed = YES;
			}]];

			observer.weakTestObjectValue = observer;
			target.weakTestObjectValue = target;

			// These observations can only result in dealloc triggered callbacks.
			[observer rac_observeKeyPath:@keypath(target.weakTestObjectValue) options:0 observer:observer block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				observerDeallocationTriggeredChange = YES;
			}];

			[target rac_observeKeyPath:@keypath(target.weakTestObjectValue) options:0 observer:observer block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				targetDeallocationTriggeredChange = YES;
			}];
		}

		expect(@(observerDisposed)).to(beTruthy());
		expect(@(observerDeallocationTriggeredChange)).to(beFalsy());

		expect(@(targetDisposed)).to(beTruthy());
		expect(@(targetDeallocationTriggeredChange)).to(beTruthy());
	});

	qck_it(@"should call the callback block for deallocation of the initial value of a single-key key path", ^{
		RACTestObject *target = [RACTestObject new];
		__block BOOL objectDisposed = NO;
		__block BOOL objectDeallocationTriggeredChange = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [RACTestObject new];
			target.weakTestObjectValue = object;
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				objectDisposed = YES;
			}]];

			[target rac_observeKeyPath:@keypath(target.weakTestObjectValue) options:0 observer:target block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				objectDeallocationTriggeredChange = YES;
			}];
		}

		expect(@(objectDisposed)).to(beTruthy());
		expect(@(objectDeallocationTriggeredChange)).to(beTruthy());
	});

	qck_it(@"should call the callback block for deallocation of an object conforming to protocol property", ^{
		RACTestObject *target = [RACTestObject new];
		__block BOOL objectDisposed = NO;
		__block BOOL objectDeallocationTriggeredChange = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [RACTestObject new];
			target.weakObjectWithProtocol = object;
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				objectDisposed = YES;
			}]];

			[target rac_observeKeyPath:@keypath(target.weakObjectWithProtocol) options:0 observer:target block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				objectDeallocationTriggeredChange = YES;
			}];
		}

		expect(@(objectDisposed)).to(beTruthy());
		expect(@(objectDeallocationTriggeredChange)).to(beTruthy());
    });
});

qck_describe(@"rac_addObserver:forKeyPath:options:block:", ^{
	qck_it(@"should add and remove an observer", ^{
		NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
		expect(operation).notTo(beNil());

		__block BOOL notified = NO;
		RACDisposable *disposable = [operation rac_observeKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew observer:self block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
			expect([change objectForKey:NSKeyValueChangeNewKey]).to(equal(@YES));

			expect(@(notified)).to(beFalsy());
			notified = YES;
		}];

		expect(disposable).notTo(beNil());

		[operation start];
		[operation waitUntilFinished];

		expect(@(notified)).toEventually(beTruthy());
	});

	qck_it(@"should accept a nil observer", ^{
		NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
		RACDisposable *disposable = [operation rac_observeKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {}];

		expect(disposable).notTo(beNil());
	});

	qck_it(@"automatically stops KVO on subclasses when the target deallocates", ^{
		void (^testKVOOnSubclass)(Class targetClass, id observer) = ^(Class targetClass, id observer) {
			__weak id weakTarget = nil;
			__weak id identifier = nil;

			@autoreleasepool {
				// Create an observable target that we control the memory management of.
				CFTypeRef target = CFBridgingRetain([[targetClass alloc] init]);
				expect((__bridge id)target).notTo(beNil());

				weakTarget = (__bridge id)target;
				expect(weakTarget).notTo(beNil());

				identifier = [(__bridge id)target rac_observeKeyPath:@"isFinished" options:0 observer:observer block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {}];
				expect(identifier).notTo(beNil());

				CFRelease(target);
			}

			expect(weakTarget).to(beNil());
			expect(identifier).to(beNil());
		};

		qck_it(@"stops KVO on NSObject subclasses", ^{
			testKVOOnSubclass(NSOperation.class, self);
		});

		qck_it(@"stops KVO on subclasses of already-swizzled classes", ^{
			testKVOOnSubclass(RACTestOperation.class, self);
		});

		qck_it(@"stops KVO on NSObject subclasses even with a nil observer", ^{
			testKVOOnSubclass(NSOperation.class, nil);
		});

		qck_it(@"stops KVO on subclasses of already-swizzled classes even with a nil observer", ^{
			testKVOOnSubclass(RACTestOperation.class, nil);
		});
	});

	qck_it(@"should automatically stop KVO when the observer deallocates", ^{
		__weak id weakObserver = nil;
		__weak id weakIdentifier = nil;

		NSOperation *operation = [[NSOperation alloc] init];

		@autoreleasepool {
			// Create an observer that we control the memory management of.
			CFTypeRef observer = CFBridgingRetain([[NSOperation alloc] init]);
			expect((__bridge id)observer).notTo(beNil());

			weakObserver = (__bridge id)observer;
			expect(weakObserver).notTo(beNil());

			id identifier = [operation rac_observeKeyPath:@"isFinished" options:0 observer:(__bridge id)observer block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {}];
			expect(identifier).notTo(beNil());

			weakIdentifier = identifier;
			expect(weakIdentifier).notTo(beNil());

			CFRelease(observer);
		}

		expect(weakObserver).to(beNil());
		expect(weakIdentifier).to(beNil());
	});

	qck_it(@"should stop KVO when the observer is disposed", ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		__block NSString *name = nil;

		RACDisposable *disposable = [queue rac_observeKeyPath:@"name" options:0 observer:self block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
			name = queue.name;
		}];

		queue.name = @"1";
		expect(name).to(equal(@"1"));
		[disposable dispose];
		queue.name = @"2";
		expect(name).to(equal(@"1"));
	});

	qck_it(@"should distinguish between observers being disposed", ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		__block NSString *name1 = nil;
		__block NSString *name2 = nil;

		RACDisposable *disposable = [queue rac_observeKeyPath:@"name" options:0 observer:self block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
			name1 = queue.name;
		}];
		[queue rac_observeKeyPath:@"name" options:0 observer:self block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
			name2 = queue.name;
		}];

		queue.name = @"1";
		expect(name1).to(equal(@"1"));
		expect(name2).to(equal(@"1"));
		[disposable dispose];
		queue.name = @"2";
		expect(name1).to(equal(@"1"));
		expect(name2).to(equal(@"2"));
	});
});

QuickSpecEnd

@implementation RACTestOperation
@end
