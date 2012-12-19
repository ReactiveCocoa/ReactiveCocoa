//
//  RACConnectableSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"

// A connectable signal encapsulates the idea of sharing one subscription to a
// signal to many subscribers. This is most often needed if the subscription to
// the underlying signal involves side-effects or shouldn't be called more than
// once.
//
// Note that you shouldn't create RACConnectableSignal manually. Instead use
// -[RACSignal publish] or -[RACSignal multicast:].
@interface RACConnectableSignal : RACSignal

// Connect to the underlying signal. Calling this multiple times does nothing
// but return the existing connection's disposable.
- (RACDisposable *)connect;

// Creates and returns a signal that calls -connect when the receiver gets its
// first subscription. Once all its subscribers are gone, subsequent
// subscriptions will reconnect to the receiver.
- (RACSignal *)autoconnect;

@end
