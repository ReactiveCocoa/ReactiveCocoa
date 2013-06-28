//
//  RACKVOWrapperSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"

#import "EXTKeyPathCoding.h"
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
// weak property should be changed to.
static NSString * const RACKVOWrapperExamplesChangeBlock = @"RACKVOWrapperExamplesChangeBlock";

// A block that returns a valid value for the weak property changed by
// RACKVOWrapperExamplesChangeBlock. The value must deallocate
// normally.
static NSString * const RACKVOWrapperExamplesValueBlock = @"RACKVOWrapperExamplesValueBlock";

// Whether RACKVOWrapperExamplesChangeBlock changes the value
// of the last key path component in the key path directly.
static NSString * const RACKVOWrapperExamplesChangesValueDirectly = @"RACKVOWrapperExamplesChangesValueDirectly";

SharedExampleGroupsBegin(RACKVOWrapperExamples)

sharedExamplesFor(RACKVOWrapperExamples, ^(NSDictionary *data) {
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
	__block void (^willChangeBlock)(BOOL) = nil;
	__block void (^didChangeBlock)(BOOL, BOOL, id) = nil;

	beforeEach(^{
		NSObject * (^targetBlock)(void) = data[RACKVOWrapperExamplesTargetBlock];
		target = targetBlock();
		keyPath = data[RACKVOWrapperExamplesKeyPath];
		changeBlock = data[RACKVOWrapperExamplesChangeBlock];
		valueBlock = data[RACKVOWrapperExamplesValueBlock];
		changesValueDirectly = [data[RACKVOWrapperExamplesChangesValueDirectly] boolValue];

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

	it(@"should call willChangeBlock before didChangeBlock when the value is changed", ^{
		__block BOOL willChangeBlockCalled = NO;
		__block BOOL didChangeBlockCalled = NO;
		[target rac_addObserver:nil forKeyPath:keyPath willChangeBlock:^(BOOL triggeredByLastKeyPathComponent) {
			willChangeBlockCalled = YES;
			expect(didChangeBlockCalled).to.beFalsy();
		} didChangeBlock:^(BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value) {
			didChangeBlockCalled = YES;
			expect(willChangeBlockCalled).to.beTruthy();
		}];

		id value = valueBlock();
		changeBlock(target, value);
		expect(willChangeBlockCalled).to.beTruthy();
		expect(didChangeBlockCalled).to.beTruthy();
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

	it(@"should call only didChangeBlock when the value is deallocated", ^{
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
		expect(didChangeBlockCallCount).to.equal(1);
		expect(didChangeBlockTriggeredByDeallocation).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SpecBegin(RACKVOWrapper)

describe(@"-rac_addObserver:forKeyPath:willChangeBlock:didChangeBlock:", ^{
	describe(@"on simple keys", ^{
		NSObject * (^targetBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};

		void (^changeBlock)(RACTestObject *, id) = ^(RACTestObject *target, id value) {
			target.weakTestObjectValue = value;
		};

		id (^valueBlock)(void) = ^{
			return [[RACTestObject alloc] init];
		};

		itShouldBehaveLike(RACKVOWrapperExamples, @{
											 RACKVOWrapperExamplesTargetBlock: targetBlock,
											 RACKVOWrapperExamplesKeyPath: @keypath(RACTestObject.new, weakTestObjectValue),
											 RACKVOWrapperExamplesChangeBlock: changeBlock,
											 RACKVOWrapperExamplesValueBlock: valueBlock,
											 RACKVOWrapperExamplesChangesValueDirectly: @YES
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

			itShouldBehaveLike(RACKVOWrapperExamples, @{
												 RACKVOWrapperExamplesTargetBlock: targetBlock,
												 RACKVOWrapperExamplesKeyPath: @keypath(RACTestObject.new, strongTestObjectValue.weakTestObjectValue),
												 RACKVOWrapperExamplesChangeBlock: changeBlock,
												 RACKVOWrapperExamplesValueBlock: valueBlock,
												 RACKVOWrapperExamplesChangesValueDirectly: @YES
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

			itShouldBehaveLike(RACKVOWrapperExamples, @{
												 RACKVOWrapperExamplesTargetBlock: targetBlock,
												 RACKVOWrapperExamplesKeyPath: @keypath([[RACTestObject alloc] init], weakTestObjectValue.strongTestObjectValue),
												 RACKVOWrapperExamplesChangeBlock: changeBlock,
												 RACKVOWrapperExamplesValueBlock: valueBlock,
												 RACKVOWrapperExamplesChangesValueDirectly: @NO
												 });
		});
	});
});

describe(@"rac_addObserver:forKeyPath:options:block:", ^{
	it(@"should add and remove an observer", ^{
		NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
		expect(operation).notTo.beNil();

		__block BOOL notified = NO;
		RACKVOTrampoline *trampoline = [operation rac_addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew block:^(id target, id observer, NSDictionary *change) {
			expect(observer).to.equal(self);
			expect([change objectForKey:NSKeyValueChangeNewKey]).to.equal(@YES);

			expect(notified).to.beFalsy();
			notified = YES;
		}];

		expect(trampoline).notTo.beNil();

		[operation start];
		[operation waitUntilFinished];

		expect(notified).will.beTruthy();
	});

	it(@"should accept a nil observer", ^{
		NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
		RACKVOTrampoline *trampoline = [operation rac_addObserver:nil forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew block:^(id target, id observer, NSDictionary *change) {
		}];
		expect(trampoline).notTo.beNil();
	});

	it(@"automatically stops KVO on subclasses when the target deallocates", ^{
		void (^testKVOOnSubclass)(Class targetClass, id observer) = ^(Class targetClass, id observer) {
			__weak id weakTarget = nil;
			__weak id identifier = nil;

			@autoreleasepool {
				// Create an observable target that we control the memory management of.
				CFTypeRef target = CFBridgingRetain([[targetClass alloc] init]);
				expect(target).notTo.beNil();

				weakTarget = (__bridge id)target;
				expect(weakTarget).notTo.beNil();

				identifier = [(__bridge id)target rac_addObserver:observer forKeyPath:@"isFinished" options:0 block:^(id target, id observer, NSDictionary *change){}];
				expect(identifier).notTo.beNil();

				CFRelease(target);
			}

			expect(weakTarget).to.beNil();
			expect(identifier).to.beNil();
		};

		it (@"stops KVO on NSObject subclasses", ^{
			testKVOOnSubclass(NSOperation.class, self);
		});

		it(@"stops KVO on subclasses of already-swizzled classes", ^{
			testKVOOnSubclass(RACTestOperation.class, self);
		});

		it (@"stops KVO on NSObject subclasses even with a nil observer", ^{
			testKVOOnSubclass(NSOperation.class, nil);
		});

		it(@"stops KVO on subclasses of already-swizzled classes even with a nil observer", ^{
			testKVOOnSubclass(RACTestOperation.class, nil);
		});
	});

	it(@"should automatically stop KVO when the observer deallocates", ^{
		__weak id weakObserver = nil;
		__weak id identifier = nil;

		NSOperation *operation = [[NSOperation alloc] init];

		@autoreleasepool {
			// Create an observer that we control the memory management of.
			CFTypeRef observer = CFBridgingRetain([[NSOperation alloc] init]);
			expect(observer).notTo.beNil();

			weakObserver = (__bridge id)observer;
			expect(weakObserver).notTo.beNil();

			identifier = [operation rac_addObserver:(__bridge id)observer forKeyPath:@"isFinished" options:0 block:^(id target, id observer, NSDictionary *change){}];
			expect(identifier).notTo.beNil();

			CFRelease(observer);
		}

		expect(weakObserver).to.beNil();
		expect(identifier).to.beNil();
	});

	it(@"should stop KVO when the observer is disposed", ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		__block NSString *name = nil;
		
		RACKVOTrampoline *trampoline = [queue rac_addObserver:self forKeyPath:@"name" options:0 block:^(id target, id observer, NSDictionary *change) {
			name = queue.name;
		}];
		
		queue.name = @"1";
		expect(name).to.equal(@"1");
		[trampoline dispose];
		queue.name = @"2";
		expect(name).to.equal(@"1");
	});

	it(@"should distinguish between observers being disposed", ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		__block NSString *name1 = nil;
		__block NSString *name2 = nil;
		
		RACKVOTrampoline *trampoline = [queue rac_addObserver:self forKeyPath:@"name" options:0 block:^(id target, id observer, NSDictionary *change) {
			name1 = queue.name;
		}];
		[queue rac_addObserver:self forKeyPath:@"name" options:0 block:^(id target, id observer, NSDictionary *change) {
			name2 = queue.name;
		}];
		
		queue.name = @"1";
		expect(name1).to.equal(@"1");
		expect(name2).to.equal(@"1");
		[trampoline dispose];
		queue.name = @"2";
		expect(name1).to.equal(@"1");
		expect(name2).to.equal(@"2");
	});
});

SpecEnd

@implementation RACTestOperation
@end
