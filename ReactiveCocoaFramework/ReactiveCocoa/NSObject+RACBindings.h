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

@interface NSObject (RACBindings)

// Bind the value of `keyPath` to the latest value of `signal`.
- (void)rac_bind:(NSString *)keyPath to:(id<RACSignal>)signal;

// Creates a binding for each object key path to the given signals.
+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(id<RACSignal>)signalOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(id<RACSignal>)signalOfProperty1;

// Create a two-way binding between `slaveKeyPath` on the receiver and
// `masterKeyPath` on the `masterObject`.
//
// The property `slaveKeypath` on the receiver will be updated with the value of
// `masterKeyPath` on `masterObject` the first time it fires a KVO notification.
// After that, the two properties will be kept in sync, mirroring each other.
//
// Returns a disposable that can be used to sever the binding.
- (RACDisposable *)rac_sync:(NSString *)slaveKeyPath to:(NSString *)masterKeyPath on:(NSObject *)masterObject;

// Analogous to `-rac_sync:to:on:`, but with an additional parameter to specify
// which options should be used for KVO.
//
// options - A mask of NSKeyValueObservingOptions specifying which options to
//           pass when subscribing to KVO notifications. Not all options make a
//           meaningful difference to how this method behaves.
//           NSKeyValueObservingOptionInitial will only be applied to the KVO on
//           `masterObject`.
- (RACDisposable *)rac_sync:(NSString *)slaveKeyPath to:(NSString *)masterKeyPath on:(NSObject *)masterObject withOptions:(NSKeyValueObservingOptions)options;

// Analogous to `-rac_sync:to:on:withOptions:`, but with additional parameters
// to transform the signals used to bind the two properties.
//
// Both parameters accept a block that is passed the original signal used by the
// binding and returns a new signal that will be used instead. The signals send
// the KVO change dictionaries.
//
// incomingTransformationBlock - The block that transforms the signal that
//                               transmits changes from `masterObject` to the
//                               receiver.
// outgoingTransformationBlock - The block that transforms the signal that
//                               transmits changes from the receiver to
//                               `masterObject`.
- (RACDisposable *)rac_sync:(NSString *)slaveKeyPath to:(NSString *)masterKeyPath on:(NSObject *)masterObject withOptions:(NSKeyValueObservingOptions)options byTransformingIncomingSignal:(RACSignalTransformationBlock)incomingTransformationBlock outgoingSignal:(RACSignalTransformationBlock)outgoingTransformationBlock;

@end
