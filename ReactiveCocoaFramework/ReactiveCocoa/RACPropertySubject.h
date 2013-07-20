//
//  RACPropertySubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

// A RACPropertySubject saves the last value sent to it and resends it to new
// subscribers. It will also resend error or completion.
//
// `next` and `completed` events sent to a RACPropertySubject are also sent to
// its bindings' subscribers. `next` and `completed` events sent to
// a RACPropertySubject's bindings are also sent to the RACPropertySubject.
//
// It is considered undefined behavior to send `error` to
// a RACPropertySubject or its bindings.
@interface RACPropertySubject : RACBinding

// Returns a new RACPropertySubject with a starting value of `nil`.
+ (instancetype)property;

// Returns a new binding of the RACPropertySubject.
//
//  - `next` events sent to the binding are sent to the binding's
//    RACPropertySubject's subscribers, and the subscribers of other RACBindings
//    from the same property subject, but are not sent to the receiver's
//    subscribers.
//  - `completed` events sent to the binding are sent to the binding's
//    RACPropertySubject's subscribers, and the subscribers of all RACBindings from
//    the same property subject, including the receiver.
//
// It is considered undefined behavior to send `error` to the binding.
- (RACBinding *)binding;

@end
