//
//  NSObject+RACBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACSignal;
@class RACDisposable;

typedef id<RACSignal> (^RACSignalTransformationBlock)(id<RACSignal>);

// Replacement for Cocoa bindings.
//
// Useful on iOS or for binding across schedulers.
@interface NSObject (RACBindings)

// Create a two-way binding between `slaveKeyPath` on the receiver and
// `masterKeyPath` on the `masterObject`.
//
// The property `receiverKeyPath` on the receiver will be updated with the value
//  of `otherKeyPath` on `otherObject`. After that, the two properties will be
// kept in sync, mirroring each other.
//
// Returns a disposable that can be used to sever the binding.
- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath;

// Analogous to `-rac_bind:toObject:withKeyPath:`, but with additional
// parameters to transform the signals used to bind the two properties.
//
// Both parameters accept a block that is passed the original signal used by the
// binding and returns a new signal that will be used instead.
//
// receiverSignalBlock - The block that transforms the signal that transmits
//                       changes from `otherObject` to the receiver.
// otherSignalBlock    - The block that transforms the signal that transmits
//                       changes from the receiver to `otherObject`.
- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath signalBlock:(RACSignalTransformationBlock)receiverSignalBlock toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath signalBlock:(RACSignalTransformationBlock)otherSignalBlock;
@end
