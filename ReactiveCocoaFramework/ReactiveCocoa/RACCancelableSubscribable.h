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
@interface RACCancelableSubscribable : RACConnectableSubscribable

- (void)cancel;

@end
