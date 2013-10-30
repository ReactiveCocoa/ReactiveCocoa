//
//  RACSignalProvider.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

/// Represents the logic for creating a signal from one input value.
///
/// Instances of this class represent a _way_ to create signals at some later
/// moment. This is useful when one or more of a signal's inputs are not yet
/// known. Instead of using a method to create the signal once you have all the
/// required information, you can instantiate this class and pass that around.
///
/// This class forms a Kleisli arrow for `RACSignal`. Conceptually, instances of
/// the class behave like -flattenMap:, except that no input signal is required
/// to map over.
@interface RACSignalProvider : NSObject

/// Creates a provider that implements its behavior using a block.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. This block must not be nil, and must not return a nil signal.
+ (instancetype)providerWithBlock:(RACSignal * (^)(id input))block;

/// Creates a provider that always returns the same signal.
///
/// signal - The signal to provide. This must not be nil.
+ (instancetype)providerWithSignal:(RACSignal *)signal;

/// A singleton provider that puts each value into a signal using +[RACSignal
/// return:].
+ (instancetype)returnProvider;

/// Creates a signal for the given value.
///
/// input - The input value, used to determine how to create the signal, and how
///         the created signal should behave. This may be nil.
///
/// Returns a new signal.
- (RACSignal *)signalWithValue:(id)input;

@end

@interface RACSignalProvider (Operations)

/// Maps each signal provided by the receiver to a new signal.
///
/// This can be used to transform the constructed signals with normal RACSignal
/// operators.
///
/// block - A block mapping a non-nil input signal to another non-nil signal.
///         This block must not be nil.
///
/// Returns a new signal provider that invokes `block` for each signal created
/// by the receiver, then returns the resulting signal.
- (instancetype)mapSignals:(RACSignal * (^)(RACSignal *original))block;

/// Creates a new provider that first creates a signal using the logic of the
/// receiver, then creates _new_ signals from each of the signal's values using
/// `nextProvider`.
///
/// In other words, this behaves like the receiver, followed by a -flattenMap:
/// using `nextProvider`.
///
/// nextProvider - The provider to apply after the receiver. This must not be nil.
///
/// Returns a new `RACSignalProvider` that combines the logic of the two providers.
- (instancetype)followedBy:(RACSignalProvider *)nextProvider;

@end
