//
//  RACKVOWrapperSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "RACKVOTrampoline.h"

@interface RACTestOperation : NSOperation
@end

SpecBegin(RACKVOWrapper)

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

it(@"automatically stops KVO on subclasses when the target deallocates", ^{
	void (^testKVOOnSubclass)(Class targetClass) = ^(Class targetClass) {
		__weak id weakTarget = nil;
		__weak id identifier = nil;

		@autoreleasepool {
			// Create an observable target that we control the memory management of.
			CFTypeRef target = CFBridgingRetain([[targetClass alloc] init]);
			expect(target).notTo.beNil();

			weakTarget = (__bridge id)target;
			expect(weakTarget).notTo.beNil();

			identifier = [(__bridge id)target rac_addObserver:self forKeyPath:@"isFinished" options:0 block:^(id target, id observer, NSDictionary *change){}];
			expect(identifier).notTo.beNil();

			CFRelease(target);
		}

		expect(weakTarget).to.beNil();
		expect(identifier).to.beNil();
	};

	it (@"stops KVO on NSObject subclasses", ^{
		testKVOOnSubclass(NSOperation.class);
	});

	it(@"stops KVO on subclasses of already-swizzled classes", ^{
		testKVOOnSubclass(RACTestOperation.class);
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

it(@"should stop KVO when the observer is removed", ^{
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	__block NSString *name = nil;
	
	RACKVOTrampoline *trampoline = [queue rac_addObserver:self forKeyPath:@"name" options:0 block:^(id target, id observer, NSDictionary *change) {
		name = queue.name;
	}];
	
	queue.name = @"1";
	expect(name).to.equal(@"1");
	[trampoline stopObserving];
	queue.name = @"2";
	expect(name).to.equal(@"1");
});

it(@"should distinguish between observers being removed", ^{
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
	[trampoline stopObserving];
	queue.name = @"2";
	expect(name1).to.equal(@"1");
	expect(name2).to.equal(@"2");
});

SpecEnd

@implementation RACTestOperation
@end
