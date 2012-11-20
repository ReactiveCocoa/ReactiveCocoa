//
//  RACCancelableSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSignal.h"

// Cancelable signal represents an operation that can be canceled. Canceling
// means that the signal is no longer valid. It will tear down all its
// subscribers.
//
// Note that cancelation is different from disposing of a subscription.
// Canceling invalidates and tears down the whole signal, whereas disposal just
// closes a particular subscription.
@interface RACCancelableSignal : RACConnectableSignal

- (void)cancel;

@end
