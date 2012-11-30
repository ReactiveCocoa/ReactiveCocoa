//
//  RACKVOWrapperSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"

SpecBegin(RACKVOWrapper)

it(@"should add and remove an observer", ^{
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
	expect(operation).notTo.beNil();

	__block BOOL notified = NO;
	id identifier = [operation rac_addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew queue:nil block:^(id target, NSDictionary *change){
		expect(target).to.equal(self);
		expect([change objectForKey:NSKeyValueChangeNewKey]).to.equal(@YES);

		expect(notified).to.beFalsy();
		notified = YES;
	}];

	expect(identifier).notTo.beNil();

	[operation start];
	[operation waitUntilFinished];

	expect(notified).will.beTruthy();
	expect([operation rac_removeObserverWithIdentifier:identifier]).to.beTruthy();
});

it(@"should automatically stop KVO when the target deallocates", ^{
	__weak id weakTarget = nil;
	__weak id identifier = nil;

	@autoreleasepool {
		// Create an observable target that we control the memory management of.
		CFTypeRef target = CFBridgingRetain([[NSOperation alloc] init]);
		expect(target).notTo.beNil();

		weakTarget = (__bridge id)target;
		expect(weakTarget).notTo.beNil();

		identifier = [(__bridge id)target rac_addObserver:self forKeyPath:@"isFinished" options:0 queue:nil block:^(id target, NSDictionary *change){}];
		expect(identifier).notTo.beNil();

		CFRelease(target);
	}

	expect(weakTarget).to.beNil();
	expect(identifier).to.beNil();
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

		identifier = [operation rac_addObserver:(__bridge id)observer forKeyPath:@"isFinished" options:0 queue:nil block:^(id observer, NSDictionary *change){}];
		expect(identifier).notTo.beNil();

		CFRelease(observer);
	}

	expect(weakObserver).to.beNil();
	expect(identifier).to.beNil();
});

SpecEnd
