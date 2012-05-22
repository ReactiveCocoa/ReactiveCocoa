//
//  RACCancelableSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSubscribable.h"


// Cancelable subscribables represents an operation that can be canceled. 
// Canceling means that the subscribable is no longer valid. It will tear down
// all its subscribers.
//
// Note that cancelation is different from disposing of a subscription.
// Canceling invalidates and tears down the whole subscribable, whereas disposal
// just closes a particular subscription.
@interface RACCancelableSubscribable : RACConnectableSubscribable

- (void)cancel;

@end
