//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"

@class RACDisposable;

// A binding of a RACPropertySubject.
//
//  - `next` events sent to the binding are sent to the binding's
//    RACPropertySubject's subscribers, and the subscribers of other RACBindings
//    from the same property subject, but are not sent to the receiver's
//    subscribers.
//  - `completed` events sent to the binding are sent to the binding's
//    RACPropertySubject's subscribers, and the subscribers of all RACBindings from
//    the same property subject, including the receiver.
//
// It is considered undefined behavior to send `error` to a RACBinding.
@interface RACBinding : RACSignal <RACSubscriber>

@end

@interface RACBinding (Deprecated)

- (RACDisposable *)bindTo:(RACBinding *)binding __attribute__((deprecated("Subscribe each binding to the other instead.")));

@end
