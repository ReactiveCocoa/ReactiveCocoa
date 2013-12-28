//
//  RACSamplingSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-27.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

/// Combines each input value with the latest value sampled from a signal, then
/// passes both into another signal generator.
///
/// Examples
///
///     RACSignal *lists = [RACObserve(self, itemList) ignore:nil];
///
///     // This action will delete its input item from the latest `itemList`
///     // when executed.
///	    RACAction *deleteAction = [[RACSamplingSignalGenerator
///	        generatorBySampling:lists forGenerator:[RACDynamicSignalGenerator generatorWithBlock:^(RACTuple *xs) {
///	            RACTupleUnpack(Item *itemToDelete, ItemList *list) = xs;
///
///	            return [APIClient deleteItem:itemToDelete fromList:list];
///	        }]]
///	        action];
@interface RACSamplingSignalGenerator : RACSignalGenerator

/// Creates a generator that will combine its inputs with the latest value of
/// `signal`, then pass both to `innerGenerator`.
///
/// signal         - A signal for the new generator to subscribe to immediately
///                  upon construction. No signals will be created using
///                  `innerGenerator` until this signal has sent at least one
///                  value. If this signal completes or errors, generated
///                  signals will also complete or error (respectively)
///                  immediately upon subscription.
/// innerGenerator - A generator accepting a `RACTuple` containing two values:
///                  the input value passed to the receiver's -signalWithValue:
///                  method, and the latest value from `signal`. The signals
///                  created by this generator will be returned from the
///                  receiver's -signalWithValue: method.
+ (instancetype)generatorBySampling:(RACSignal *)signal forGenerator:(RACSignalGenerator *)innerGenerator;

/// Creates a signal that will invoke the underlying signal generator with
/// a tuple of two values: `input`, and the latest value received from the
/// sampled signal that was given upon initialization.
///
/// Returns a signal that, upon subscription, will wait until at least one value
/// has been sampled, then create a signal using the underlying generator and
/// forward all of its events. If the sampled signal has completed or errored by
/// the time the returned signal is subscribed to, or before one value is sent,
/// the `completed` or `error` event will be forwarded to the subscriber.
- (RACSignal *)signalWithValue:(id)input;

@end
