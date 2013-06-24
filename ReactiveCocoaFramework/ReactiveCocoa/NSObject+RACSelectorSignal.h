//
//  NSObject+RACSelectorSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

// The domain for any errors originating from -rac_signalForSelector:.
extern NSString * const RACSelectorSignalErrorDomain;

// -rac_signalForSelector: was going to add a new method implementation for
// `selector`, but another thread added an implementation before it was able to.
//
// This will _not_ occur for cases where a method implementation exists before
// -rac_signalForSelector: is invoked.
extern const NSInteger RACSelectorSignalErrorMethodSwizzlingRace;

@interface NSObject (RACSelectorSignal)

// Creates a signal associated with the receiver, which will send a tuple of the
// method's arguments each time the given selector is invoked.
//
// If the selector is already implemented on the receiver, the existing
// implementation will be invoked _before_ the signal fires.
//
// If the selector is not yet implemented on the receiver, the injected
// implementation will have a `void` return type and accept only object
// arguments. Invoking the added implementation with non-object values, or
// expecting a return value, will result in undefined behavior.
//
// This is useful for changing an event or delegate callback into a signal. For
// example, on an NSView:
//
//     [[view rac_signalForSelector:@selector(mouseDown:)] subscribeNext:^(NSEvent *event) {
//         NSLog(@"mouse button pressed: %@", event);
//     }];
//
// selector - The selector for whose invocations are to be observed. If it
//            doesn't exist, it will be implemented to accept object arguments
//            and return void.
//
// Returns a signal which will send a tuple of arguments upon each invocation of
// the selector, or an error in RACSelectorSignalErrorDomain if a runtime
// call fails. `next` events will be sent synchronously from the thread that
// invoked the method.
- (RACSignal *)rac_signalForSelector:(SEL)selector;

@end
