//
//  NSObject+RACLifting.h
//  iOSDemo
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

@class RACSignal;

@interface NSObject (RACLifting)

// Lifts the selector on the receiver into the reactive world. The selector will
// be invoked whenever any signal argument sends a value, but only after each
// signal has sent a value.
//
// It will replay the most recently sent value to new subscribers.
//
// This does not support C strings, arrays, unions, or structs other than
// CGRect, CGSize, CGPoint, and NSRange.
//
// selector    - The selector on self to invoke.
// firstSignal - The signal corresponding to the first method argument. This
//               must not be nil.
// ...         - A list of RACSignals corresponding to the remaining arguments.
//               There must be a non-nil signal for each method argument.
//
// Examples
//
//   [button rac_liftSelector:@selector(setTitleColor:forState:) withSignals:textColorSignal, [RACSignal return:@(UIControlStateNormal)]];
//
// Returns a signal which sends the return value from each invocation of the
// selector. If the selector returns void, it instead sends RACUnit.defaultUnit.
// It completes only after all the signal arguments complete.
- (RACSignal *)rac_liftSelector:(SEL)selector withSignals:(RACSignal *)firstSignal, ... NS_REQUIRES_NIL_TERMINATION;

// Like -rac_liftSelector:withSignals:, but accepts an array instead of
// a variadic list of arguments.
- (RACSignal *)rac_liftSelector:(SEL)selector withSignalsFromArray:(NSArray *)signals;

// Like -rac_liftSelector:withSignals: but invokes a block instead of a selector.
//
// This currently only supports block of up to 15 arguments. If you need any
// more, you need to reconsider your life.
//
// block         - The block to invoke. All arguments must be signals, and the block
//                 must return an object. The block must not be nil.
// firstSignal   - The signal corresponding to the first block argument. This
//                 must not be nil.
// ...           - A list of RACSignals corresponding to the remaining
//                 arguments. There must be a non-nil signal for each block
//                 argument.
//
// Returns a signal which sends the return value from each invocation of the
// block. It completes only after all the signal arguments complete.
- (RACSignal *)rac_liftBlock:(id)block withSignals:(RACSignal *)firstSignal, ... NS_REQUIRES_NIL_TERMINATION;

// Like -rac_liftBlock:withSignals:, but accepts an array instead of
// a variadic list of arguments.
- (RACSignal *)rac_liftBlock:(id)block withSignalsFromArray:(NSArray *)signals;

@end

@interface NSObject (RACLiftingDeprecated)

- (RACSignal *)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... __attribute__((deprecated("Use -rac_liftSelector:withSignals: instead")));
- (RACSignal *)rac_liftSelector:(SEL)selector withObjectsFromArray:(NSArray *)args __attribute__((deprecated("Use -rac_liftSelector:withSignalsFromArray: instead")));
- (RACSignal *)rac_liftBlock:(id)block withArguments:(id)arg, ... NS_REQUIRES_NIL_TERMINATION __attribute__((deprecated("Use -rac_liftBlock:withSignals: instead")));
- (RACSignal *)rac_liftBlock:(id)block withArgumentsFromArray:(NSArray *)args __attribute__((deprecated("Use -rac_liftBlock:withSignalsFromArray: instead")));

@end

@interface NSObject (RACLiftingUnavailable)

- (instancetype)rac_lift __attribute__((unavailable("Use -rac_liftSelector:withSignals: instead")));

@end
