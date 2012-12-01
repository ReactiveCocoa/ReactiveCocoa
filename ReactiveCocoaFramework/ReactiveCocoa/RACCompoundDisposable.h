//
//  RACCompoundDisposable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDisposable.h"

// A disposable of disposables. When it is disposed, it disposes of all its
// contained disposables.
//
// If -addDisposable: is called after the compound disposable has been disposed
// of, the given disposable is immediately disposed. This allows a compound
// disposable to act as a stand-in for a disposable that will be delivered
// asynchronously.
@interface RACCompoundDisposable : RACDisposable

// Creates and returns a new compound disposable.
+ (instancetype)compoundDisposable;

// Creates and returns a new compound disposable containing the given
// disposables.
+ (instancetype)compoundDisposableWithDisposables:(NSArray *)disposables;

// Adds the given disposable. If the receiving disposable has already been
// disposed of, the given disposable is disposed immediately.
//
// disposable - The disposable to add. Cannot be nil.
- (void)addDisposable:(RACDisposable *)disposable;

@end
