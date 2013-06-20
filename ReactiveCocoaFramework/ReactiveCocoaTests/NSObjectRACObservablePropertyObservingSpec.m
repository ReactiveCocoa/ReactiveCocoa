//
//  NSObjectRACObservablePropertyObserving.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/06/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACObservablePropertyObserving.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"

// The name of the examples.
static NSString * const RACObservablePropertyObservingExamples = @"RACObservablePropertyObservingExamples";

// A block that returns an object to observe in the examples.
static NSString * const RACObservablePropertyObservingExamplesTargetBlock = @"RACObservablePropertyObservingExamplesTargetBlock";

// The key path to observe in the examples.
//
// The key path must have at least one weak property in it.
static NSString * const RACObservablePropertyObservingExamplesKeyPath = @"RACObservablePropertyObservingExamplesKeyPath";

// A block that changes the value of a weak property in the observed key path.
// The block is passed the object the example is observing and the new value the
// weak property should be changed to.
static NSString * const RACObservablePropertyObservingExamplesChangeBlock = @"RACObservablePropertyObservingExamplesChangeBlock";

// A block that returns a valid value for the weak property changed by
// RACObservablePropertyObservingExamplesChangeBlock. The value must deallocate
// normally.
static NSString * const RACObservablePropertyObservingExamplesValueBlock = @"RACObservablePropertyObservingExamplesValueBlock";

// Whether RACObservablePropertyObservingExamplesChangeBlock changes the value
// of the last key path component in the key path directly.
static NSString * const RACObservablePropertyObservingExamplesChangesValueDirectly = @"RACObservablePropertyObservingExamplesChangesValueDirectly";

SharedExampleGroupsBegin(RACObservablePropertyObservingExamples)

sharedExamplesFor(RACObservablePropertyObservingExamples, ^(NSDictionary *data) {
	__block NSObject *target = nil;
	__block NSString *keyPath = nil;
	__block void (^changeBlock)(NSObject *, id) = nil;
	__block id (^valueBlock)(void) = nil;
	__block BOOL changesValueDirectly = NO;
	
	__block NSUInteger willChangeBlockCallCount = 0;
	__block NSUInteger didChangeBlockCallCount = 0;
	__block BOOL willChangeBlockTriggeredByLastKeyPathComponent = NO;
	__block BOOL didChangeBlockTriggeredByLastKeyPathComponent = NO;
	__block BOOL didChangeBlockTriggeredByDeallocation = NO;
	__block void(^willChangeBlock)(BOOL) = nil;
	__block void(^didChangeBlock)(BOOL, BOOL, id) = nil;
	
	beforeEach(^{
		target = ((NSObject *(^)(void))data[RACObservablePropertyObservingExamplesTargetBlock])();
		keyPath = data[RACObservablePropertyObservingExamplesKeyPath];
		changeBlock = data[RACObservablePropertyObservingExamplesChangeBlock];
		valueBlock = data[RACObservablePropertyObservingExamplesValueBlock];
		changesValueDirectly = [data[RACObservablePropertyObservingExamplesChangesValueDirectly] boolValue];
		
		willChangeBlockCallCount = 0;
		didChangeBlockCallCount = 0;
		
		willChangeBlock = [^(BOOL triggeredByLastKeyPathComponent) {
			willChangeBlockTriggeredByLastKeyPathComponent = triggeredByLastKeyPathComponent;
			++willChangeBlockCallCount;
		} copy];
		didChangeBlock = [^(BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value) {
			didChangeBlockTriggeredByLastKeyPathComponent = triggeredByLastKeyPathComponent;
			didChangeBlockTriggeredByDeallocation = triggeredByDeallocation;
			++didChangeBlockCallCount;
		} copy];
	});

	afterEach(^{
		target = nil;
		keyPath = nil;
		changeBlock = nil;
		valueBlock = nil;
		changesValueDirectly = NO;

		willChangeBlock = nil;
		didChangeBlock = nil;
	});

	it(@"should not call willChangeBlock or didChangeBlock on add", ^{
		[target rac_addObserver:nil forKeyPath:keyPath willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock];
		expect(willChangeBlockCallCount).to.equal(0);
		expect(didChangeBlockCallCount).to.equal(0);
	});
	
	it(@"should call willChangeBlock and didChangeBlock once per change", ^{
		[target rac_addObserver:nil forKeyPath:keyPath willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock];
		willChangeBlockCallCount = 0;
		didChangeBlockCallCount = 0;
		
		id value1 = valueBlock();
		changeBlock(target, value1);
		expect(willChangeBlockCallCount).to.equal(1);
		expect(didChangeBlockCallCount).to.equal(1);
		expect(willChangeBlockTriggeredByLastKeyPathComponent).to.equal(changesValueDirectly);
		expect(didChangeBlockTriggeredByLastKeyPathComponent).to.equal(changesValueDirectly);
		expect(didChangeBlockTriggeredByDeallocation).to.beFalsy();

		id value2 = valueBlock();
		changeBlock(target, value2);
		expect(willChangeBlockCallCount).to.equal(2);
		expect(didChangeBlockCallCount).to.equal(2);
		expect(willChangeBlockTriggeredByLastKeyPathComponent).to.equal(changesValueDirectly);
		expect(didChangeBlockTriggeredByLastKeyPathComponent).to.equal(changesValueDirectly);
		expect(didChangeBlockTriggeredByDeallocation).to.beFalsy();
	});
	
	it(@"should not call willChangeBlock and didChangeBlock after it's been disposed", ^{
		RACDisposable *disposable = [target rac_addObserver:nil forKeyPath:keyPath willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock];
		willChangeBlockCallCount = 0;
		didChangeBlockCallCount = 0;
		
		[disposable dispose];
		expect(willChangeBlockCallCount).to.equal(0);
		expect(didChangeBlockCallCount).to.equal(0);
		
		id value = valueBlock();
		changeBlock(target, value);
		expect(willChangeBlockCallCount).to.equal(0);
		expect(didChangeBlockCallCount).to.equal(0);
	});
	
	it(@"should call only didChangeBlock at least once when the value is deallocated", ^{
		__block BOOL valueDidDealloc = NO;

		[target rac_addObserver:nil forKeyPath:keyPath willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock];
		
		@autoreleasepool {
			NSObject *value __attribute__((objc_precise_lifetime)) = valueBlock();
			[value.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				valueDidDealloc = YES;
			}]];
			
			changeBlock(target, value);
			willChangeBlockCallCount = 0;
			didChangeBlockCallCount = 0;
		}
		
		expect(valueDidDealloc).to.beTruthy();
		expect(willChangeBlockCallCount).to.equal(0);
		expect(didChangeBlockCallCount).to.beGreaterThanOrEqualTo(1);
		expect(didChangeBlockTriggeredByDeallocation).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SpecBegin(RACObservablePropertyObserving)

describe(@"-rac_addObserver:forKeyPath:willChangeBlock:didChangeBlock:", ^{
	describe(@"on simple keys", ^{
		NSObject *(^targetBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};
		
		void (^changeBlock)(RACTestObject *, id) = ^(RACTestObject *target, id value) {
			target.weakTestObjectValue = value;
		};
		
		id (^valueBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};
		
		itShouldBehaveLike(RACObservablePropertyObservingExamples, @{
			RACObservablePropertyObservingExamplesTargetBlock: targetBlock,
			RACObservablePropertyObservingExamplesKeyPath: @keypath([[RACTestObject alloc] init], weakTestObjectValue),
			RACObservablePropertyObservingExamplesChangeBlock: changeBlock,
			RACObservablePropertyObservingExamplesValueBlock: valueBlock,
			RACObservablePropertyObservingExamplesChangesValueDirectly: @YES
		});
	});
	
	describe(@"on composite key paths'", ^{
		describe(@"last key path components", ^{
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
			
			itShouldBehaveLike(RACObservablePropertyObservingExamples, @{
				RACObservablePropertyObservingExamplesTargetBlock: targetBlock,
				RACObservablePropertyObservingExamplesKeyPath: @keypath([[RACTestObject alloc] init], strongTestObjectValue.weakTestObjectValue),
				RACObservablePropertyObservingExamplesChangeBlock: changeBlock,
				RACObservablePropertyObservingExamplesValueBlock: valueBlock,
				RACObservablePropertyObservingExamplesChangesValueDirectly: @YES
			});
		});
		
		describe(@"intermediate key path components", ^{
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
			
			itShouldBehaveLike(RACObservablePropertyObservingExamples, @{
				RACObservablePropertyObservingExamplesTargetBlock: targetBlock,
				RACObservablePropertyObservingExamplesKeyPath: @keypath([[RACTestObject alloc] init], weakTestObjectValue.strongTestObjectValue),
				RACObservablePropertyObservingExamplesChangeBlock: changeBlock,
				RACObservablePropertyObservingExamplesValueBlock: valueBlock,
				RACObservablePropertyObservingExamplesChangesValueDirectly: @NO
			});
		});
	});
});

SpecEnd
