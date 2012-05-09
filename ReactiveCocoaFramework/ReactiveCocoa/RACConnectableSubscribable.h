//
//  RACConnectableSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"


// A connectable subscribable encapsulates the idea of sharing one subscription
// to a subscribable to many subscribers. This is most often needed if the 
// subscription to the underlying subscribable involves side-effects or 
// shouldn't be called more than once.
//
// Note that you shouldn't create RACConnectableSubscribables manually. Instead
// use -[RACSubscribable publish] or -[RACSubscribable multicast:].
@interface RACConnectableSubscribable : RACSubscribable

// Connect to the underlying subscribable. Calling this multiple times does
// nothing but return the existing connection's disposable.
- (RACDisposable *)connect;

// Creates and returns a subscribable that calls -connect when the receiver
// gets its first subscription. Once all its subscribers are gone, subsequent
// subscriptions will reconnect to the receiver.
- (RACSubscribable *)autoconnect;

@end
