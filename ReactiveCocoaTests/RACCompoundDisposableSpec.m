//
//  RACCompoundDisposableSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACCompoundDisposable.h"

QuickSpecBegin(RACCompoundDisposableSpec)

qck_it(@"should dispose of all its contained disposables", ^{
	__block BOOL d1Disposed = NO;
	RACDisposable *d1 = [RACDisposable disposableWithBlock:^{
		d1Disposed = YES;
	}];

	__block BOOL d2Disposed = NO;
	RACDisposable *d2 = [RACDisposable disposableWithBlock:^{
		d2Disposed = YES;
	}];

	__block BOOL d3Disposed = NO;
	RACDisposable *d3 = [RACDisposable disposableWithBlock:^{
		d3Disposed = YES;
	}];

	__block BOOL d4Disposed = NO;
	RACDisposable *d4 = [RACDisposable disposableWithBlock:^{
		d4Disposed = YES;
	}];

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ d1, d2, d3 ]];
	[disposable addDisposable:d4];

	expect(@(d1Disposed)).to(beFalsy());
	expect(@(d2Disposed)).to(beFalsy());
	expect(@(d3Disposed)).to(beFalsy());
	expect(@(d4Disposed)).to(beFalsy());
	expect(@(disposable.disposed)).to(beFalsy());

	[disposable dispose];

	expect(@(d1Disposed)).to(beTruthy());
	expect(@(d2Disposed)).to(beTruthy());
	expect(@(d3Disposed)).to(beTruthy());
	expect(@(d4Disposed)).to(beTruthy());
	expect(@(disposable.disposed)).to(beTruthy());
});

qck_it(@"should dispose of any added disposables immediately if it's already been disposed", ^{
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	[disposable dispose];

	RACDisposable *d = [[RACDisposable alloc] init];

	expect(@(d.disposed)).to(beFalsy());
	[disposable addDisposable:d];
	expect(@(d.disposed)).to(beTruthy());
});

qck_it(@"should work when initialized with -init", ^{
	RACCompoundDisposable *disposable = [[RACCompoundDisposable alloc] init];

	__block BOOL disposed = NO;
	RACDisposable *d = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	[disposable addDisposable:d];
	expect(@(disposed)).to(beFalsy());

	[disposable dispose];
	expect(@(disposed)).to(beTruthy());
});

qck_it(@"should work when initialized with +disposableWithBlock:", ^{
	__block BOOL compoundDisposed = NO;
	RACCompoundDisposable *disposable = [RACCompoundDisposable disposableWithBlock:^{
		compoundDisposed = YES;
	}];

	__block BOOL disposed = NO;
	RACDisposable *d = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	[disposable addDisposable:d];
	expect(@(disposed)).to(beFalsy());
	expect(@(compoundDisposed)).to(beFalsy());

	[disposable dispose];
	expect(@(disposed)).to(beTruthy());
	expect(@(compoundDisposed)).to(beTruthy());
});

qck_it(@"should allow disposables to be removed", ^{
	RACCompoundDisposable *disposable = [[RACCompoundDisposable alloc] init];
	RACDisposable *d = [[RACDisposable alloc] init];

	[disposable addDisposable:d];
	[disposable removeDisposable:d];

	[disposable dispose];
	expect(@(d.disposed)).to(beFalsy());
});

QuickSpecEnd
