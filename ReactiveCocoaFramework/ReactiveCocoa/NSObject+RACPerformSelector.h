//
//  NSObject+RACPerformSelector.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (RACPerformSelector)

// Allows you to pass subscribables for non-subscribable arguments. It will
// invoke the given selector on the receiver each time any subscribable
// argument sends a new value.
//
// Examples:
//
//   [button rac_performSelector:@selector(setTitleColor:forState:) withObjects:textColorSubscribable, @(UIControlStateNormal), nil];
//   [[UIApplication sharedApplication] rac_performSelector:@selector(setNetworkActivityIndicatorVisible:) withObjects:subscribable, nil];
- (void)rac_performSelector:(SEL)selector withObjects:(id)arg, ... NS_REQUIRES_NIL_TERMINATION;

@end
