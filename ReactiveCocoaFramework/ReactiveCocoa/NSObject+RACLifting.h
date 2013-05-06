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

// Like -rac_liftSelector:withObjects: but differs by taking the arguments in
// array form. As a consequence of using an array, nil argument values must be
// represented by RACTupleNil.
//
// selector - The selector on self to invoke.
// args     - The arguments array.
//
// See -rac_liftSelector:withObjects:
- (RACSignal *)rac_liftSelector:(SEL)selector withObjectsFromArray:(NSArray *)args;

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

// Like -rac_liftBlock:withArguments: but differs by taking the arguments in
// array form. As a consequence of using an array, nil argument values must be
// represented by RACTupleNil.
//
// block - The block to invoke. All its arguments must be objects. Cannot return
//         void. Cannot be nil. This currently only supports block of up to 15
//         arguments. If you need any more, you need to reconsider your life.
// args  - The arguments array.
//
// See -rac_liftSelector:withArguments:
- (RACSignal *)rac_liftBlock:(id)block withArgumentsFromArray:(NSArray *)args;

// Like -rac_liftSelector:withObjects: but uses higher order messaging instead of
// a selector and argument list.
//
// Signals are only supported as message arguments where the method signature
// expects an argument of object type.
//
// Examples
//
//     [button.rac_lift setTitleColor:textColorSignal forState:UIControlStateNormal];
//     RAC(self.textField.textColor) = [self.rac_lift colorForString:self.field.rac_textSignal];
//
// Returns a proxy object that lifts messages into the reactive world and
// forwards them to its receiver. Messages which have an object return type will
// return a signal that replays the most recently sent value to new subscribers;
// messages with void return type will return void. All other messages (such as
// those with primitive return type) are disallowed.
- (instancetype)rac_lift;

@end
