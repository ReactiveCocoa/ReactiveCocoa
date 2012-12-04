//
//  NSObjectRACBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 03/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "EXTKeyPathCoding.h"
#import "RACSignal.h"
#import "RACScheduler.h"

@interface TestClass : NSObject
@property (strong) NSString *name;
@end

@implementation TestClass
@end

SpecBegin(NSObjectRACBindings)

describe(@"two-way bindings", ^{
	__block TestClass *a;
	__block TestClass *b;
	__block TestClass *c;
	__block NSString *testName1;
	__block NSString *testName2;
	__block NSString *testName3;
	
	before(^{
		a = [[TestClass alloc] init];
		b = [[TestClass alloc] init];
		c = [[TestClass alloc] init];
		testName1 = @"sync it!";
		testName2 = @"sync it again!";
		testName3 = @"sync it once more!";
	});
	
	describe(@"-rac_bind:signalBlock:toObject:withKeyPath:signalBlock:", ^{
		
		it(@"should keep objects' properties in sync", ^{
			[a rac_bind:@keypath(a.name) signalBlock:nil toObject:b withKeyPath:@keypath(b.name) signalBlock:nil];
			expect(a.name).to.beNil();
			expect(b.name).to.beNil();
			a.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
			b.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
			a.name = nil;
			expect(a.name).to.beNil();
			expect(b.name).to.beNil();
		});
		
		it(@"should take the master's value at the start", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_bind:@keypath(a.name) signalBlock:nil toObject:b withKeyPath:@keypath(b.name) signalBlock:nil];
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		});
		
		it(@"should bind transitively", ^{
			a.name = testName1;
			b.name = testName2;
			c.name = testName3;
			[a rac_bind:@keypath(a.name) signalBlock:nil toObject:b withKeyPath:@keypath(b.name) signalBlock:nil];
			[b rac_bind:@keypath(b.name) signalBlock:nil toObject:c withKeyPath:@keypath(c.name) signalBlock:nil];
			expect(a.name).to.equal(testName3);
			expect(b.name).to.equal(testName3);
			expect(c.name).to.equal(testName3);
			c.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
			expect(c.name).to.equal(testName1);
			b.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
			expect(c.name).to.equal(testName2);
			a.name = testName3;
			expect(a.name).to.equal(testName3);
			expect(b.name).to.equal(testName3);
			expect(c.name).to.equal(testName3);
		});
		
		it(@"should bind even if the initial update is the same as the other object's value", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_bind:@keypath(a.name) signalBlock:nil toObject:b withKeyPath:@keypath(b.name) signalBlock:nil];
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
			b.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		});
		
		it(@"should bind even if the initial update is the same as the receiver's value", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_bind:@keypath(a.name) signalBlock:nil toObject:b withKeyPath:@keypath(b.name) signalBlock:nil];
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
			b.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
		});
		
		it(@"should trasform values of bound properties", ^{
			[a rac_bind:@keypath(a.name) signalBlock:^(id<RACSignal> incoming) {
				return [incoming map:^(NSString *x) {
					return x.stringByDeletingPathExtension;
				}];
			} toObject:b withKeyPath:@keypath(b.name) signalBlock:^(id<RACSignal> outgoing) {
				return [outgoing map:^(NSString *x) {
					return [NSString stringWithFormat:@"%@.%@", x, c.name];
				}];
			}];
			[c rac_bind:@keypath(c.name) signalBlock:^(id<RACSignal> incoming) {
				return [incoming map:^(NSString *x) {
					return x.pathExtension;
				}];
			} toObject:b withKeyPath:@keypath(b.name) signalBlock:^(id<RACSignal> outgoing) {
				return [outgoing map:^(NSString *x) {
					return [NSString stringWithFormat:@"%@.%@", a.name, x];
				}];
			}];
			expect(a.name).to.beNil();
			expect(b.name).to.beNil();
			expect(c.name).to.beNil();
			b.name = @"file.txt";
			expect(a.name).to.equal(@"file");
			expect(b.name).to.equal(@"file.txt");
			expect(c.name).to.equal(@"txt");
			a.name = @"file2";
			expect(a.name).to.equal(@"file2");
			expect(b.name).to.equal(@"file2.txt");
			expect(c.name).to.equal(@"txt");
			c.name = @"rtf";
			expect(a.name).to.equal(@"file2");
			expect(b.name).to.equal(@"file2.rtf");
			expect(c.name).to.equal(@"rtf");
		});
	});
	
	it(@"should run transformations only once per change, and only in one direction", ^{
		__block NSUInteger aCounter = 0;
		__block NSUInteger cCounter = 0;
		RACSignalTransformationBlock incrementACounter = ^(id<RACSignal> incoming) {
			return [incoming doNext:^(id _) {
				aCounter++;
			}];
		};
		RACSignalTransformationBlock incrementCCounter = ^(id<RACSignal> incoming) {
			return [incoming doNext:^(id _) {
				cCounter++;
			}];
		};
		expect(aCounter).to.equal(0);
		expect(cCounter).to.equal(0);
		[a rac_bind:@keypath(a.name) signalBlock:incrementACounter toObject:b withKeyPath:@keypath(b.name) signalBlock:incrementACounter];
		[c rac_bind:@keypath(c.name) signalBlock:incrementCCounter toObject:b withKeyPath:@keypath(b.name) signalBlock:incrementCCounter];
		expect(aCounter).to.equal(1);
		expect(cCounter).to.equal(1);
		b.name = testName1;
		expect(aCounter).to.equal(2);
		expect(cCounter).to.equal(2);
		a.name = testName2;
		expect(aCounter).to.equal(3);
		expect(cCounter).to.equal(3);
		c.name = testName3;
		expect(aCounter).to.equal(4);
		expect(cCounter).to.equal(4);
	});
	
	it(@"should handle the bound objects being changed at the same time on different threads", ^{
		RACScheduler *aScheduler = RACScheduler.backgroundScheduler;
		RACScheduler *bScheduler = RACScheduler.backgroundScheduler;
		
		[a rac_bind:@keypath(a.name) signalBlock:^(id<RACSignal> incoming) {
			return [incoming deliverOn:aScheduler];
		} toObject:b withKeyPath:@keypath(b.name) signalBlock:^(id<RACSignal> outgoing) {
			return [outgoing deliverOn:bScheduler];
		}];
		
		a.name = nil;
		expect(a.name).to.beNil();
		expect(b.name).to.beNil();
		__block volatile uint32_t aReady = 0;
		__block volatile uint32_t bReady = 0;
		[aScheduler schedule:^{
			OSAtomicOr32Barrier(1, &aReady);
			while (!bReady) {
				// do nothing while waiting for b, sleeping might hide the race
			}
		 a.name = testName1;
		}];
		[bScheduler schedule:^{
			OSAtomicOr32Barrier(1, &bReady);
			while (!aReady) {
				// do nothing while waiting for a, sleeping might hide the race
			}
			b.name = testName2;
		}];
		while (![a.name isEqual:testName2] || ![b.name isEqual:testName1]) {
			sleep(1);
		}
		if ([a.name isEqual:testName1]) {
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
		} else {
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		}
	});
});

SpecEnd
