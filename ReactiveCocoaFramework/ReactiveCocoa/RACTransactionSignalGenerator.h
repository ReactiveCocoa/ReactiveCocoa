//
//  RACTransactionSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-12.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// A generator that keeps track of all the "transactions" (signals) it
/// produces.
@interface RACTransactionSignalGenerator : RACSignalGenerator

/// Decorates the given generator with transactional behavior.
///
/// After invoking this method, `generator` should generally not be used
/// directly, because it will not track transactions. Instead, use the
/// initialized transaction generator.
///
/// This is the designated initializer of this class.
///
/// generator - The generator to add transactional functionality to. This must
///             not be nil.
- (id)initWithGenerator:(RACSignalGenerator *)generator;

/// A signal of signals, containing each "transaction" (signal) produced
/// whenever -signalWithValue: is invoked upon the receiver.
///
/// This signal delivers its events on an indeterminate thread, and completes
/// when the receiver deallocates.
@property (nonatomic, strong, readonly) RACSignal *transactions;

@end
