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

// Adds an implementation of `selector` to the receiver which will send the
// receiver each time it is invoked.
//
// `selector` shouldn't already be implemented on the receiver. It will not
// swizzle an existing implementation.
//
// This is most useful for implementing a method which is called to communicate
// events to the receiver. For example, in an NSView:
//   [self rac_signalForSelector:@selector(mouseDown:)];
//
// selector - The selector for which an implementation should be added. It
//            shouldn't already be implemented on the receiver. It must be of
//            the type:
//              - (void)selector:(id)argument
//
// Returns a signal which will send the receiver on each invocation.
- (RACSignal *)rac_signalForSelector:(SEL)selector;

@end
