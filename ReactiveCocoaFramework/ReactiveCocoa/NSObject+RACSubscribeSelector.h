//
//  NSObject+RACSubscribeSelector.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACSubscribeSelector)

// Allows you to pass signals for non-signal arguments. It will invoke the given
// selector on the receiver each time any signal argument sends a new value.
// Signal arguments default to nil/0.
//
// This does not support struct, union, or C array arguments.
//
// Examples:
//
//   [button rac_subscribeSelector:@selector(setTitleColor:forState:) withObjects:textColorSignal, @(UIControlStateNormal)];
//   [[UIApplication sharedApplication] rac_subscribeSelector:@selector(setNetworkActivityIndicatorVisible:) withObjects:signal];
- (void)rac_subscribeSelector:(SEL)selector withObjects:(id)arg, ...;

@end
