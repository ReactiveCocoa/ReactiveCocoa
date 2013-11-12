//
//  RACDynamicSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// A generator that implements its behavior using a block.
@interface RACDynamicSignalGenerator : RACSignalGenerator

/// Initializes the receiver to generate signals using the given block.
///
/// block - Describes how to create a signal from an input value, which may be
///         nil. This block must not be nil, and must not return a nil signal.
- (id)initWithBlock:(RACSignal * (^)(id input))block;

@end
