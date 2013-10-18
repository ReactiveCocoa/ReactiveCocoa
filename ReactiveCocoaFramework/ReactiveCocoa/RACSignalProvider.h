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
/// Instances of this class representing a _way_ to create signals at some later
/// moment. This is useful when one or more of a signal's inputs are not yet
/// known. Instead of using a method to create the signal once you have all the
/// required information, you can instantiate this class and pass that around.
///
/// This class forms a Kleisli arrow for `RACSignal`. Conceptually, instances of
/// the class behave like -flattenMap:, except that no input signal is required
/// to map over.
@interface RACSignalProvider : NSObject

/// Initializes the receiver with a block provider.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. This block must not be nil, and must not return a nil signal.
- (id)initWithBlock:(RACSignal * (^)(id input))block;

/// Creates a new provider that first creates a signal using the logic of
/// `firstProvider`, then creates _new_ signals from each of the signal's values
/// using the logic of the receiver.
///
/// In other words, this behaves like `firstProvider`, followed by a -flattenMap:
/// using the receiver.
///
/// firstProvider - The provider to apply first. This must not be nil.
///
/// Returns a new signal provider that combines the logic of the two providers.
- (instancetype)pullback:(RACSignalProvider *)firstProvider;

/// Creates a signal for the given value.
///
/// input - The input value, used to determine how to create the signal, and how
///         the created signal should behave. This may be nil.
///
/// Returns a new signal.
- (RACSignal *)provide:(id)input;

@end
