//
//  RACSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

/// An abstract class representing the logic for creating a signal from one
/// input value.
///
/// Instances represent a way to create signals at some later moment. Depending
/// on the specific subclass, there may also be side effects involved in the
/// generated signals and/or the generation algorithm itself.
///
/// This class forms an arrow `a ~> Signal b`. More simply, instances of the
/// class behave like -flattenMap:, except that they can be applied directly to
/// values (not just existing signals).
@interface RACSignalGenerator : NSObject

/// Instantiates a generator that implements its behavior using a block.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. This block must not be nil, and must not return a nil signal.
+ (RACSignalGenerator *)generatorWithBlock:(RACSignal * (^)(id input))block;

/// Creates a signal for the given value.
///
/// Depending on the specific subclass, this method and/or the created signal
/// may have side effects.
///
/// input - The input value, used to determine how to create the signal, and how
///         the created signal should behave. This may be nil.
///
/// Returns a new signal.
- (RACSignal *)signalWithValue:(id)input;

@end
