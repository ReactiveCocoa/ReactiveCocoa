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
// This does not support C array, union, or struct types other than CGRect,
// CGSize, and CGPoint.
//
// If it is not given any signal arguments, it will immediately invoke the
// selector with the arguments.
//
// selector - The selector on self to invoke.
// arg      - The variadic list of arguments. Doesn't need to be nil-terminated
//            since we can figure out the number of arguments from the selector's
//            method signature.
//
// Examples
//
//   [button rac_liftSelector:@selector(setTitleColor:forState:) withObjects:textColorSignal, @(UIControlStateNormal)];
//
// Returns a signal which sends the return value from each invocation of the
// selector. If the selector returns void, it instead sends RACUnit.defaultUnit.
// It completes only after all the signal arguments complete.
- (RACSignal *)rac_liftSelector:(SEL)selector withObjects:(id)arg, ...;

// Like -rac_liftSelector:withObjects: but invokes the block instead of a selector.
//
// It will replay the most recently sent value to new subscribers.
//
// block - The block to invoke. All its arguments must be objects. Cannot return
//         void. Cannot be nil. This currently only supports block of up to 15
//         arguments. If you need any more, you need to reconsider your life.
// arg   - The variadic, nil-terminated list of arguments.
//
// Returns a signal which sends the return value from each invocation of the
// block. It completes only after all the signal arguments complete.
- (RACSignal *)rac_liftBlock:(id)block withArguments:(id)arg, ... NS_REQUIRES_NIL_TERMINATION;

@end
