//
//  RACKVOChannelSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTestObject.h"
#import "RACChannelExamples.h"
#import "RACPropertySignalExamples.h"

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOChannel.h"
#import "RACSignal+Operations.h"

QuickSpecBegin(RACKVOChannelSpec)

qck_describe(@"RACKVOChannel", ^{
	__block RACTestObject *object;
	__block RACKVOChannel *channel;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	qck_beforeEach(^{
		object = [[RACTestObject alloc] init];
		channel = [[RACKVOChannel alloc] initWithTarget:object keyPath:@keypath(object.stringValue) nilValue:nil];
	});
	
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal) {
		RACKVOChannel *channel = [[RACKVOChannel alloc] initWithTarget:testObject keyPath:keyPath nilValue:nilValue];
		[signal subscribe:channel.followingTerminal];
	};
	
	qck_itBehavesLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});
	
	qck_itBehavesLike(RACChannelExamples, ^{
		return @{
			RACChannelExampleCreateBlock: [^{
				return [[RACKVOChannel alloc] initWithTarget:object keyPath:@keypath(object.stringValue) nilValue:nil];
			} copy]
		};
	});
	
	qck_it(@"should send the object's current value when subscribed to followingTerminal", ^{
		__block id receivedValue = @"received value should not be this";
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to(beNil());
		
		object.stringValue = value1;
		[[channel.followingTerminal take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];

		expect(receivedValue).to(equal(value1));
	});
	
	qck_it(@"should send the object's new value on followingTerminal when it's changed", ^{
		object.stringValue = value1;

		NSMutableArray *receivedValues = [NSMutableArray array];
		[channel.followingTerminal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		object.stringValue = value2;
		object.stringValue = value3;
		expect(receivedValues).to(equal(values));
	});
	
	qck_it(@"should set the object's value using values sent to the followingTerminal", ^{
		expect(object.stringValue).to(beNil());

		[channel.followingTerminal sendNext:value1];
		expect(object.stringValue).to(equal(value1));

		[channel.followingTerminal sendNext:value2];
		expect(object.stringValue).to(equal(value2));
	});
	
	qck_it(@"should be able to subscribe to signals", ^{
		NSMutableArray *receivedValues = [NSMutableArray array];
		[object rac_observeKeyPath:@keypath(object.stringValue) options:0 observer:self block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
			[receivedValues addObject:value];
		}];

		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:value1];
			[subscriber sendNext:value2];
			[subscriber sendNext:value3];
			return nil;
		}];

		[signal subscribe:channel.followingTerminal];
		expect(receivedValues).to(equal(values));
	});

	qck_it(@"should complete both terminals when the target deallocates", ^{
		__block BOOL leadingCompleted = NO;
		__block BOOL followingCompleted = NO;
		__block BOOL deallocated = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			RACKVOChannel *channel = [[RACKVOChannel alloc] initWithTarget:object keyPath:@keypath(object.stringValue) nilValue:nil];
			[channel.leadingTerminal subscribeCompleted:^{
				leadingCompleted = YES;
			}];

			[channel.followingTerminal subscribeCompleted:^{
				followingCompleted = YES;
			}];

			expect(@(deallocated)).to(beFalsy());
			expect(@(leadingCompleted)).to(beFalsy());
			expect(@(followingCompleted)).to(beFalsy());
		}

		expect(@(deallocated)).to(beTruthy());
		expect(@(leadingCompleted)).to(beTruthy());
		expect(@(followingCompleted)).to(beTruthy());
	});

	qck_it(@"should deallocate when the target deallocates", ^{
		__block BOOL targetDeallocated = NO;
		__block BOOL channelDeallocated = NO;

		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				targetDeallocated = YES;
			}]];

			RACKVOChannel *channel = [[RACKVOChannel alloc] initWithTarget:object keyPath:@keypath(object.stringValue) nilValue:nil];
			[channel.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				channelDeallocated = YES;
			}]];

			expect(@(targetDeallocated)).to(beFalsy());
			expect(@(channelDeallocated)).to(beFalsy());
		}

		expect(@(targetDeallocated)).to(beTruthy());
		expect(@(channelDeallocated)).to(beTruthy());
	});
});

qck_describe(@"RACChannelTo", ^{
	__block RACTestObject *a;
	__block RACTestObject *b;
	__block RACTestObject *c;
	__block NSString *testName1;
	__block NSString *testName2;
	__block NSString *testName3;
	
	qck_beforeEach(^{
		a = [[RACTestObject alloc] init];
		b = [[RACTestObject alloc] init];
		c = [[RACTestObject alloc] init];
		testName1 = @"sync it!";
		testName2 = @"sync it again!";
		testName3 = @"sync it once more!";
	});
	
	qck_it(@"should keep objects' properties in sync", ^{
		RACChannelTo(a, stringValue) = RACChannelTo(b, stringValue);
		expect(a.stringValue).to(beNil());
		expect(b.stringValue).to(beNil());
		
		a.stringValue = testName1;
		expect(a.stringValue).to(equal(testName1));
		expect(b.stringValue).to(equal(testName1));
		
		b.stringValue = testName2;
		expect(a.stringValue).to(equal(testName2));
		expect(b.stringValue).to(equal(testName2));
		
		a.stringValue = nil;
		expect(a.stringValue).to(beNil());
		expect(b.stringValue).to(beNil());
	});
	
	qck_it(@"should keep properties identified by keypaths in sync", ^{
		RACChannelTo(a, strongTestObjectValue.stringValue) = RACChannelTo(b, strongTestObjectValue.stringValue);
		a.strongTestObjectValue = [[RACTestObject alloc] init];
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		
		a.strongTestObjectValue.stringValue = testName1;
		expect(a.strongTestObjectValue.stringValue).to(equal(testName1));
		expect(b.strongTestObjectValue.stringValue).to(equal(testName1));
		expect(a.strongTestObjectValue).notTo(equal(b.strongTestObjectValue));
		
		b.strongTestObjectValue = nil;
		expect(a.strongTestObjectValue.stringValue).to(beNil());
		
		c.stringValue = testName2;
		b.strongTestObjectValue = c;
		expect(a.strongTestObjectValue.stringValue).to(equal(testName2));
		expect(b.strongTestObjectValue.stringValue).to(equal(testName2));
		expect(a.strongTestObjectValue).notTo(equal(b.strongTestObjectValue));
	});
	
	qck_it(@"should update properties identified by keypaths when the intermediate values change", ^{
		RACChannelTo(a, strongTestObjectValue.stringValue) = RACChannelTo(b, strongTestObjectValue.stringValue);
		a.strongTestObjectValue = [[RACTestObject alloc] init];
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		c.stringValue = testName1;
		b.strongTestObjectValue = c;
		
		expect(a.strongTestObjectValue.stringValue).to(equal(testName1));
		expect(a.strongTestObjectValue).notTo(equal(b.strongTestObjectValue));
	});
	
	qck_it(@"should update properties identified by keypaths when the channel was created when one of the two objects had an intermediate nil value", ^{
		RACChannelTo(a, strongTestObjectValue.stringValue) = RACChannelTo(b, strongTestObjectValue.stringValue);
		b.strongTestObjectValue = [[RACTestObject alloc] init];
		c.stringValue = testName1;
		a.strongTestObjectValue = c;
		
		expect(a.strongTestObjectValue.stringValue).to(equal(testName1));
		expect(b.strongTestObjectValue.stringValue).to(equal(testName1));
		expect(a.strongTestObjectValue).notTo(equal(b.strongTestObjectValue));
	});
	
	qck_it(@"should take the value of the object being bound to at the start", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;

		RACChannelTo(a, stringValue) = RACChannelTo(b, stringValue);
		expect(a.stringValue).to(equal(testName2));
		expect(b.stringValue).to(equal(testName2));
	});
	
	qck_it(@"should update the value even if it's the same value the object had before it was bound", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;

		RACChannelTo(a, stringValue) = RACChannelTo(b, stringValue);
		expect(a.stringValue).to(equal(testName2));
		expect(b.stringValue).to(equal(testName2));
		
		b.stringValue = testName1;
		expect(a.stringValue).to(equal(testName1));
		expect(b.stringValue).to(equal(testName1));
	});
	
	qck_it(@"should bind transitively", ^{
		a.stringValue = testName1;
		b.stringValue = testName2;
		c.stringValue = testName3;

		RACChannelTo(a, stringValue) = RACChannelTo(b, stringValue);
		RACChannelTo(b, stringValue) = RACChannelTo(c, stringValue);
		expect(a.stringValue).to(equal(testName3));
		expect(b.stringValue).to(equal(testName3));
		expect(c.stringValue).to(equal(testName3));
		
		c.stringValue = testName1;
		expect(a.stringValue).to(equal(testName1));
		expect(b.stringValue).to(equal(testName1));
		expect(c.stringValue).to(equal(testName1));
		
		b.stringValue = testName2;
		expect(a.stringValue).to(equal(testName2));
		expect(b.stringValue).to(equal(testName2));
		expect(c.stringValue).to(equal(testName2));
		
		a.stringValue = testName3;
		expect(a.stringValue).to(equal(testName3));
		expect(b.stringValue).to(equal(testName3));
		expect(c.stringValue).to(equal(testName3));
	});
	
	qck_it(@"should bind changes made by KVC on arrays", ^{
		b.arrayValue = @[];
		RACChannelTo(a, arrayValue) = RACChannelTo(b, arrayValue);

		[[b mutableArrayValueForKeyPath:@keypath(b.arrayValue)] addObject:@1];
		expect(a.arrayValue).to(equal(b.arrayValue));
	});
	
	qck_it(@"should bind changes made by KVC on sets", ^{
		b.setValue = [NSSet set];
		RACChannelTo(a, setValue) = RACChannelTo(b, setValue);

		[[b mutableSetValueForKeyPath:@keypath(b.setValue)] addObject:@1];
		expect(a.setValue).to(equal(b.setValue));
	});
	
	qck_it(@"should bind changes made by KVC on ordered sets", ^{
		b.orderedSetValue = [NSOrderedSet orderedSet];
		RACChannelTo(a, orderedSetValue) = RACChannelTo(b, orderedSetValue);

		[[b mutableOrderedSetValueForKeyPath:@keypath(b.orderedSetValue)] addObject:@1];
		expect(a.orderedSetValue).to(equal(b.orderedSetValue));
	});
	
	qck_it(@"should handle deallocation of intermediate objects correctly even without support from KVO", ^{
		__block BOOL wasDisposed = NO;

		RACChannelTo(a, weakTestObjectValue.stringValue) = RACChannelTo(b, strongTestObjectValue.stringValue);
		b.strongTestObjectValue = [[RACTestObject alloc] init];

		@autoreleasepool {
			RACTestObject *object = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];
			
			a.weakTestObjectValue = object;
			object.stringValue = testName1;
			
			expect(@(wasDisposed)).to(beFalsy());
			expect(b.strongTestObjectValue.stringValue).to(equal(testName1));
		}
		
		expect(@(wasDisposed)).toEventually(beTruthy());
		expect(b.strongTestObjectValue.stringValue).to(beNil());
	});
	
	qck_it(@"should stop binding when disposed", ^{
		RACChannelTerminal *aTerminal = RACChannelTo(a, stringValue);
		RACChannelTerminal *bTerminal = RACChannelTo(b, stringValue);

		a.stringValue = testName1;
		RACDisposable *disposable = [aTerminal subscribe:bTerminal];

		expect(a.stringValue).to(equal(testName1));
		expect(b.stringValue).to(equal(testName1));

		a.stringValue = testName2;
		expect(a.stringValue).to(equal(testName2));
		expect(b.stringValue).to(equal(testName2));

		[disposable dispose];

		a.stringValue = testName3;
		expect(a.stringValue).to(equal(testName3));
		expect(b.stringValue).to(equal(testName2));
	});
	
	qck_it(@"should use the nilValue when sent nil", ^{
		RACChannelTerminal *terminal = RACChannelTo(a, integerValue, @5);
		expect(@(a.integerValue)).to(equal(@0));

		[terminal sendNext:@2];
		expect(@(a.integerValue)).to(equal(@2));

		[terminal sendNext:nil];
		expect(@(a.integerValue)).to(equal(@5));
	});

	qck_it(@"should use the nilValue when an intermediate object is nil", ^{
		__block BOOL wasDisposed = NO;

		RACChannelTo(a, weakTestObjectValue.integerValue, @5) = RACChannelTo(b, strongTestObjectValue.integerValue, @5);
		b.strongTestObjectValue = [[RACTestObject alloc] init];

		@autoreleasepool {
			RACTestObject *object = [[RACTestObject alloc] init];
			[object.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];
			
			a.weakTestObjectValue = object;
			object.integerValue = 2;

			expect(@(wasDisposed)).to(beFalsy());
			expect(@(b.strongTestObjectValue.integerValue)).to(equal(@2));
		}
		
		expect(@(wasDisposed)).toEventually(beTruthy());
		expect(@(b.strongTestObjectValue.integerValue)).to(equal(@5));
	});
});

QuickSpecEnd
