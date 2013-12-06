//
//  RACQueuedSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// A generator that enforces serial execution across all of its generated
/// signals.
///
/// Whenever the result of -signalWithValue: is subscribed to, no work will
/// actually be performed until all of the signals subscribed to previously have
/// completed or errored.
@interface RACQueuedSignalGenerator : RACSignalGenerator

/// Instantiates a queued generator that will create signals using the given
/// signal generator.
///
/// generator - A generator used to create the signals that will be enqueued by
///             the receiver. This must not be nil.
+ (instancetype)queuedGeneratorWithGenerator:(RACSignalGenerator *)generator;

@end
