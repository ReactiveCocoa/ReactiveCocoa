//
//  RACDisposableSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACDisposable.h"
#import "RACScopedDisposable.h"

QuickSpecBegin(RACDisposableSpec)

qck_it(@"should initialize without a block", ^{
	RACDisposable *disposable = [[RACDisposable alloc] init];
	expect(disposable).notTo(beNil());
	expect(@(disposable.disposed)).to(beFalsy());

	[disposable dispose];
	expect(@(disposable.disposed)).to(beTruthy());
});

qck_it(@"should execute a block upon disposal", ^{
	__block BOOL disposed = NO;
	RACDisposable *disposable = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	expect(disposable).notTo(beNil());
	expect(@(disposed)).to(beFalsy());
	expect(@(disposable.disposed)).to(beFalsy());

	[disposable dispose];
	expect(@(disposed)).to(beTruthy());
	expect(@(disposable.disposed)).to(beTruthy());
});

qck_it(@"should not dispose upon deallocation", ^{
	__block BOOL disposed = NO;
	__weak RACDisposable *weakDisposable = nil;

	@autoreleasepool {
		RACDisposable *disposable = [RACDisposable disposableWithBlock:^{
			disposed = YES;
		}];

		weakDisposable = disposable;
		expect(weakDisposable).notTo(beNil());
	}

	expect(weakDisposable).to(beNil());
	expect(@(disposed)).to(beFalsy());
});

qck_it(@"should create a scoped disposable", ^{
	__block BOOL disposed = NO;
	__weak RACScopedDisposable *weakDisposable = nil;

	@autoreleasepool {
		RACScopedDisposable *disposable __attribute__((objc_precise_lifetime)) = [RACScopedDisposable disposableWithBlock:^{
			disposed = YES;
		}];

		weakDisposable = disposable;
		expect(weakDisposable).notTo(beNil());
		expect(@(disposed)).to(beFalsy());
	}

	expect(weakDisposable).to(beNil());
	expect(@(disposed)).to(beTruthy());
});

QuickSpecEnd
