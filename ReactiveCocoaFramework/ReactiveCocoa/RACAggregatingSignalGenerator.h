//
//  RACAggregatingSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// Generates signals using another signal generator, then aggregates them,
/// allowing them to be combined in arbitrary ways and adjust how their work is
/// performed.
///
/// Note that the signals sent on `generatedSignals` _must_ be subscribed to for
/// any work to actually be performed.
///
/// This class should not be instantiated directly. Use -[RACSignalGenerator
/// aggregate] instead.
///
/// Examples
///
///		RACAggregatingSignalGenerator *queueGenerator = [[RACDynamicSignalGenerator
///			generatorWithBlock:^(id value) {
///				return [[RACSignal return:value] delay:1];
///			}]
///			aggregate];
///
///		// Combine the generated signals in order, enforcing serial execution.
///		[[queueGenerator.generatedSignals
///			concat]
///			subscribeNext:^(id value) {
///				NSLog(@"%@", value);
///			}];
///
///		[[queueGenerator signalWithValue:@"foo"] subscribeCompleted:^{
///			NSLog(@"Sent 'foo'");
///		}];
///
///		[[queueGenerator signalWithValue:@"bar"] subscribeCompleted:^{
///			// This won't occur until @"foo" has been sent (after the 1 second
///			// delay applied above).
///			NSLog(@"Sent 'bar'");
///		}];
@interface RACAggregatingSignalGenerator : RACSignalGenerator

/// A signal of the signals created by the underlying generator.
///
/// A new signal will be sent on `generatedSignals` whenever a result of
/// -signalWithValue: is subscribed to.
///
/// Note that no work will be performed until the inner signals here are
/// subscribed to.
@property (nonatomic, strong, readonly) RACSignal *generatedSignals;

/// Creates a signal for the given value.
///
/// This method will:
///
///  1. Invoke the signal generator that the receiver was initialized with,
///     creating a signal G from `input`.
///  2. Return a signal R.
///
/// Upon _each_ subscription to the returned signal R, signal G will be sent
/// upon `generatedSignals`. All events from _all subscriptions_ to signal
/// G will be forwarded to signal R's subscriber. Disposing of a subscription to
/// signal G does not affect the subscription to signal R.
///
/// **Note:** If signal G never sends `error` or `completed` to any of its
/// subscribers (perhaps because it is disposed too soon), the returned signal
/// R will never terminate.
///
/// input - A value to pass to the signal generator that the receiver was
///         initialized with. This may be nil, if the underlying generator
///         supports it.
///
/// Returns a signal which will generate a signal using `input`, send it upon
/// `generatedSignals`, then pass through all of its events.
- (RACSignal *)signalWithValue:(id)input;

@end

@interface RACSignalGenerator (RACAggregatingSignalGeneratorAdditions)

/// Returns an aggregating generator that will create signals using the
/// receiver.
- (RACAggregatingSignalGenerator *)aggregate;

@end
