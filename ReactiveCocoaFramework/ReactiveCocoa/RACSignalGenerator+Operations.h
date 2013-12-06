//
//  RACSignalGenerator+Operations.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

@class RACQueuedSignalGenerator;

@interface RACSignalGenerator (Operations)

/// Creates a new generator that first creates a signal using the logic of the
/// receiver, then transforms the created signal's values using `otherGenerator`.
///
/// In other words, this behaves like the receiver, followed by a -flattenMap:
/// using `otherGenerator`.
///
/// otherGenerator - The generator to apply after the receiver. This must not be nil.
///
/// Returns a new `RACSignalGenerator` that combines the logic of the two
/// generators.
- (RACSignalGenerator *)postcompose:(RACSignalGenerator *)otherGenerator;

/// Creates a new generator based on the receiver that serializes its generated
/// signals, so they can never execute in parallel.
///
/// Returns a new `RACQueuedSignalGenerator` that will use the receiver to
/// generate signals.
- (RACQueuedSignalGenerator *)serialize;

@end
