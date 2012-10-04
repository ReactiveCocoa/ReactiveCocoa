//
//  NSObject+RACSubscribeSelector.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACSubscribeSelector)

// Allows you to pass subscribables for non-subscribable arguments. It will
// invoke the given selector on the receiver each time any subscribable
// argument sends a new value. Subscribable arguments default to nil/0.
//
// This does not support struct, union, or C array arguments.
//
// Examples:
//
//   [button rac_subscribeSelector:@selector(setTitleColor:forState:) withObjects:textColorSubscribable, @(UIControlStateNormal)];
//   [[UIApplication sharedApplication] rac_subscribeSelector:@selector(setNetworkActivityIndicatorVisible:) withObjects:subscribable];
- (void)rac_subscribeSelector:(SEL)selector withObjects:(id)arg, ...;

@end
