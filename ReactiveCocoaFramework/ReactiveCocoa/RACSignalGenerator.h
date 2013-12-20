//
//  RACSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSignal.h"

/// An abstract class representing the logic for creating a signal from one
/// input value.
///
/// Instances represent a way to create signals at some later moment. Depending
/// on the specific subclass, there may also be side effects involved in the
/// generated signals and/or the generation algorithm itself.
///
/// This class represents a function `a -> Signal b`. More simply, instances of the
/// class behave like -flattenMap:, except that they can be applied directly to
/// values (not just existing signals).
///
/// This class is not meant to be instantiated directly. Instead, use one of the
/// available subclasses or extensions on `RACSignal`. If you need behavior that
/// cannot be achieved with `RACDynamicSignalGenerator` or another subclass, you
/// may create your own by overriding `-signalWithValue:`.
@interface RACSignalGenerator : NSObject

/// Creates a signal for the given value.
///
/// This method must be overridden by subclasses. Depending on the specific
/// subclass, this method and/or the created signal may have side effects.
///
/// input - The input value, used to determine how to create the signal, and how
///         the created signal should behave. This may be nil.
///
/// Returns a new signal.
- (RACSignal *)signalWithValue:(id)input;

@end

@interface RACSignal (RACSignalGeneratorAdditions)

/// Creates a constant signal generator from the receiver.
///
/// Returns a signal generator that will discard input to -signalWithValue: and
/// always return the receiver.
- (RACSignalGenerator *)signalGenerator;

@end

@interface RACSignalGenerator (Operations)

/// Passes the outputs of the receiver through `otherGenerator`.
///
/// This behaves like the receiver, followed by a -flattenMap: using `otherGenerator`.
///
/// otherGenerator - The generator to apply after the receiver. This must not be nil.
///
/// Returns a new `RACSignalGenerator` that combines the logic of the two
/// generators.
- (RACSignalGenerator *)postcompose:(RACSignalGenerator *)otherGenerator;

@end
