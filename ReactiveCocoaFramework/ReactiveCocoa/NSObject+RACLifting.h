//
//  NSObject+RACLifting.h
//  iOSDemo
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

@protocol RACSubscribable;

@interface NSObject (RACLifting)

// Lifts the selector on self into the reactive world. The selector will be
// invoked whenever any subscribable argument sends a value, but only after each
// subscribable has sent a value.
//
// It will replay the most recently sent value to new subscribers.
//
// This does not support struct, union, or C array arguments.
//
// selector - The selector on self to invoke.
// arg      - The variadic list of arguments. Doesn't need to be nil-terminated
//            since we can figure out the number of arguments from the selector's
//            method signature.
//
// Examples
//
//   [button rac_liftSelector:@selector(setTitleColor:forState:) withObjects:textColorSubscribable, @(UIControlStateNormal)];
//
// Returns a subscribable which sends the return value from each invocation of
// the selector. If the selector returns void, it instead sends nil. It
// completes only after all the subscribable arguments complete.
- (id<RACSubscribable>)rac_liftSelector:(SEL)selector withObjects:(id)arg, ...;

// Like -rac_lift:withObjects: but invokes the block instead of a selector.
//
// It will replay the most recently sent value to new subscribers.
//
// block - The block to invoke. All its arguments must be objects. Cannot return
//         void. Cannot be nil.
// arg   - The variadic, nil-terminated list of arguments.
//
// Returns a subscribable which sends the return value from each invocation of
// the block. It completes only after all the subscribable arguments complete.
- (id<RACSubscribable>)rac_liftBlock:(id)block withArguments:(id)arg, ... NS_REQUIRES_NIL_TERMINATION;

@end
