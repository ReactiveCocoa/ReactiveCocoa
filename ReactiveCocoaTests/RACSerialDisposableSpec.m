//
//  RACSerialDisposableSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSerialDisposable.h"

SpecBegin(RACSerialDisposable)

it(@"should initialize with -init", ^{
	RACSerialDisposable *serial = [[RACSerialDisposable alloc] init];
	expect(serial).notTo.beNil();
	expect(serial.disposable).to.beNil();
});

it(@"should initialize an inner disposable with -initWithBlock:", ^{
	__block BOOL disposed = NO;
	RACSerialDisposable *serial = [RACSerialDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	expect(serial).notTo.beNil();
	expect(serial.disposable).notTo.beNil();

	[serial.disposable dispose];
	expect(serial.disposed).to.beFalsy();
	expect(disposed).to.beTruthy();
});

it(@"should initialize with a disposable", ^{
	RACDisposable *inner = [[RACDisposable alloc] init];
	RACSerialDisposable *serial = [RACSerialDisposable serialDisposableWithDisposable:inner];
	expect(serial).notTo.beNil();
	expect(serial.disposable).to.equal(inner);
});

it(@"should dispose of the inner disposable", ^{
	__block BOOL disposed = NO;
	RACDisposable *inner = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	RACSerialDisposable *serial = [RACSerialDisposable serialDisposableWithDisposable:inner];
	expect(serial.disposed).to.beFalsy();
	expect(disposed).to.beFalsy();

	[serial dispose];
	expect(serial.disposed).to.beTruthy();
	expect(serial.disposable).to.beNil();
	expect(disposed).to.beTruthy();
});

it(@"should dispose of a new inner disposable if it's already been disposed", ^{
	__block BOOL disposed = NO;
	RACDisposable *inner = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	RACSerialDisposable *serial = [[RACSerialDisposable alloc] init];
	expect(serial.disposed).to.beFalsy();

	[serial dispose];
	expect(serial.disposed).to.beTruthy();
	expect(disposed).to.beFalsy();

	serial.disposable = inner;
	expect(disposed).to.beTruthy();
	expect(serial.disposable).to.beNil();
});

it(@"should allow the inner disposable to be set to nil", ^{
	__block BOOL disposed = NO;
	RACDisposable *inner = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	RACSerialDisposable *serial = [RACSerialDisposable serialDisposableWithDisposable:inner];
	expect(disposed).to.beFalsy();

	serial.disposable = nil;
	expect(serial.disposable).to.beNil();

	serial.disposable = inner;
	expect(serial.disposable).to.equal(inner);

	[serial dispose];
	expect(disposed).to.beTruthy();
	expect(serial.disposable).to.beNil();
});

it(@"should swap inner disposables", ^{
	__block BOOL firstDisposed = NO;
	RACDisposable *first = [RACDisposable disposableWithBlock:^{
		firstDisposed = YES;
	}];

	__block BOOL secondDisposed = NO;
	RACDisposable *second = [RACDisposable disposableWithBlock:^{
		secondDisposed = YES;
	}];

	RACSerialDisposable *serial = [RACSerialDisposable serialDisposableWithDisposable:first];
	expect([serial swapInDisposable:second]).to.equal(first);

	expect(serial.disposed).to.beFalsy();
	expect(firstDisposed).to.beFalsy();
	expect(secondDisposed).to.beFalsy();
	
	[serial dispose];
	expect(serial.disposed).to.beTruthy();
	expect(serial.disposable).to.beNil();

	expect(firstDisposed).to.beFalsy();
	expect(secondDisposed).to.beTruthy();
});

it(@"should release the inner disposable upon deallocation", ^{
	__weak RACDisposable *weakInnerDisposable;
	__weak RACSerialDisposable *weakSerialDisposable;

	@autoreleasepool {
		RACDisposable *innerDisposable __attribute__((objc_precise_lifetime)) = [[RACDisposable alloc] init];
		weakInnerDisposable = innerDisposable;

		RACSerialDisposable *serialDisposable __attribute__((objc_precise_lifetime)) = [[RACSerialDisposable alloc] init];
		serialDisposable.disposable = innerDisposable;
		weakSerialDisposable = serialDisposable;
	}

	expect(weakSerialDisposable).to.beNil();
	expect(weakInnerDisposable).to.beNil();
});

SpecEnd
