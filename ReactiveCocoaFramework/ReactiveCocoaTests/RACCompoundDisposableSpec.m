//
//  RACCompoundDisposableSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCompoundDisposable.h"

SpecBegin(RACCompoundDisposable)

it(@"should dispose of all its contained disposables", ^{
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

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ d1, d2 ]];
	[disposable addDisposable:d3];
	expect(d1Disposed).to.beFalsy();
	expect(d2Disposed).to.beFalsy();
	expect(d3Disposed).to.beFalsy();

	[disposable dispose];
	expect(d1Disposed).to.beTruthy();
	expect(d2Disposed).to.beTruthy();
	expect(d3Disposed).to.beTruthy();
});

it(@"should dispose of any added disposables immediately if it's already been disposed", ^{
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	[disposable dispose];

	__block BOOL disposed = NO;
	RACDisposable *d = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	expect(disposed).to.beFalsy();
	[disposable addDisposable:d];
	expect(disposed).to.beTruthy();
});

it(@"should work when initialized with -init", ^{
	RACCompoundDisposable *disposable = [[RACCompoundDisposable alloc] init];

	__block BOOL disposed = NO;
	RACDisposable *d = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	[disposable addDisposable:d];
	expect(disposed).to.beFalsy();

	[disposable dispose];
	expect(disposed).to.beTruthy();
});

it(@"should allow disposables to be removed", ^{
	RACCompoundDisposable *disposable = [[RACCompoundDisposable alloc] init];

	__block BOOL disposed = NO;
	RACDisposable *d = [RACDisposable disposableWithBlock:^{
		disposed = YES;
	}];

	[disposable addDisposable:d];
	[disposable removeDisposable:d];

	[disposable dispose];
	expect(disposed).to.beFalsy();
});

SpecEnd
