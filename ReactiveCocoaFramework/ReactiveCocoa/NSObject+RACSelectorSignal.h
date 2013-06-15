//
//  NSObject+RACSelectorSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface NSObject (RACSelectorSignal)

// Creates a signal associated with the receiver which will send a tuple of the
// arguments each time the given selector is invoked. Applicable whether the
// selector exists or not. When the selector does not exists, a method will be
// defined whose argument types are all objects and returns void.
//
// This is useful for implementing a method which is called to communicate
// events to the receiver. For example, in an NSView:
//   [someSignal takeUntil:[self rac_signalForSelector:@selector(mouseDown:)]];
//
// selector - The selector for whose invocations are to be observed. If it
//            doesn't exist, it'll be defined to return void and take objects.
//
// Returns a signal which will send the argument on each invocation.
- (RACSignal *)rac_signalForSelector:(SEL)selector;

// The same as -rac_signalForSelector: but with class methods.
+ (RACSignal *)rac_signalForSelector:(SEL)selector;

@end
