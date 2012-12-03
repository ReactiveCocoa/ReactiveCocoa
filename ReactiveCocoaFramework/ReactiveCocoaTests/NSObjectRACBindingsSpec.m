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
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) RACScheduler *homeScheduler;
@end

@implementation TestClass

- (void)setName:(NSString *)name {
	if (self.homeScheduler) {
		expect(RACScheduler.currentScheduler).to.equal(self.homeScheduler);
	}
	_name = name;
}

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
	
	describe(@"-rac_sync:to:on:", ^{
		it(@"should keep objects' properties in sync", ^{
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b];
			expect(a.name).to.beNil();
			expect(b.name).to.beNil();
			a.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
			b.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		});
		
		it(@"should take the master's value at the start", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b];
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		});
		
		it(@"should bind transitively", ^{
			a.name = testName1;
			b.name = testName2;
			c.name = testName3;
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b];
			[b rac_sync:@keypath(b.name) to:@keypath(c.name) on:c];
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
	});
	
	describe(@"-rac_sync:to:on:withOptions:", ^{
		it(@"should ignore updates on the slave object before the master object updates", ^{
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b withOptions:0];
			expect(a.name).to.beNil();
			expect(b.name).to.beNil();
			a.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.beNil();
			a.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.beNil();
			b.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
		});
		
		it(@"should bind even if the initial update is the same as the master object's value", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b withOptions:0];
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName2);
			b.name = testName2;
			expect(a.name).to.equal(testName2);
			expect(b.name).to.equal(testName2);
		});
		
		it(@"should bind even if the initial update is the same as the master object's value", ^{
			a.name = testName1;
			b.name = testName2;
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b withOptions:0];
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName2);
			b.name = testName1;
			expect(a.name).to.equal(testName1);
			expect(b.name).to.equal(testName1);
		});
	});
	
	describe(@"-rac_sync:to:on:withOptions:byTransformingIncomingSignal:outgoingSignal:", ^{
		it(@"should trasform values of bound properties", ^{
			[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b withOptions:0 byTransformingIncomingSignal:^(id<RACSignal> incoming) {
				return [incoming map:^(NSString *x) {
					return x.stringByDeletingPathExtension;
				}];
			} outgoingSignal:^(id<RACSignal> outgoing) {
				return [outgoing map:^(NSString *x) {
					if (c.name == nil) {
						return x;
					}
					return [x stringByAppendingFormat:@".%@", c.name];
				}];
			}];
			[c rac_sync:@keypath(c.name) to:@keypath(b.name) on:b withOptions:0 byTransformingIncomingSignal:^(id<RACSignal> incoming) {
				return [incoming map:^(NSString *x) {
					return x.pathExtension;
				}];
			} outgoingSignal:^(id<RACSignal> outgoing) {
				return [outgoing map:^(NSString *x) {
					if (x == nil) {
						return a.name;
					}
					return [a.name stringByAppendingFormat:@".%@", x];
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
		RACSignalTransformationBlock (^incrementCounter)(NSUInteger *) = ^(NSUInteger *counter){
			return ^(id<RACSignal> incoming) {
				return [incoming doNext:^(id _) {
					++*counter;
				}];
			};
		};
		[a rac_sync:@keypath(a.name) to:@keypath(b.name) on:b withOptions:0 byTransformingIncomingSignal:incrementCounter(&aCounter) outgoingSignal:incrementCounter(&aCounter)];
		[c rac_sync:@keypath(c.name) to:@keypath(b.name) on:b withOptions:0 byTransformingIncomingSignal:incrementCounter(&cCounter) outgoingSignal:incrementCounter(&cCounter)];
		expect(aCounter).to.equal(0);
		expect(cCounter).to.equal(0);
		b.name = testName1;
		expect(aCounter).to.equal(1);
		expect(cCounter).to.equal(1);
		a.name = testName2;
		expect(aCounter).to.equal(2);
		expect(cCounter).to.equal(2);
		c.name = testName3;
		expect(aCounter).to.equal(3);
		expect(cCounter).to.equal(3);
	});
});

SpecEnd
