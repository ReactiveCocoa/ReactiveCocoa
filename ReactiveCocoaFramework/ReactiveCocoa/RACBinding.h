//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"

@class RACBindingEndpoint;

// A two-way binding.
//
// Conceptually, RACBinding can be thought of as a bidirectional connection,
// composed of two controllable signals that work in parallel.
//
// For example, when binding between a view and a model:
//
//       View      ------>      Model
//  `leftEndpoint` <------ `rightEndpoint`
//
// Whenever the model changes, the new value is _sent on_ the `rightEndpoint`,
// and _received from_ the `leftEndpoint`.
//
// Likewise, whenever the user changes the value of the view, that value is sent
// on the `leftEndpoint`, and received in the model from the `rightEndpoint`.
@interface RACBinding : NSObject

// One endpoint of the binding.
//
// The latest value sent to the `rightEndpoint` (if any) will be sent
// immediately to new subscribers of the `leftEndpoint`.
@property (nonatomic, strong, readonly) RACBindingEndpoint *leftEndpoint;

// The other endpoint of the binding.
//
// The latest value sent to the `leftEndpoint` (if any) will be sent
// immediately to new subscribers of the `rightEndpoint`.
@property (nonatomic, strong, readonly) RACBindingEndpoint *rightEndpoint;

@end

// Represents one end of a RACBinding.
//
// An endpoint is similar to a socket or pipe -- it represents one end of
// a connection (the RACBinding, in this case). Values sent to this endpoint
// will _not_ be received by its subscribers. Instead, the values will be sent
// to the subscribers of the RACBinding's _other_ endpoint.
//
// For example, when using the `leftEndpoint`, _sent_ values can only be
// _received_ from the `rightEndpoint`, and vice versa.
//
// To make it easy to terminate a RACBinding, `error` and `completed` events
// sent to either endpoint will be received by the subscribers of _both_
// endpoints.
//
// Do not instantiate this class directly. Create a RACBinding instead.
@interface RACBindingEndpoint : RACSignal <RACSubscriber>

// Subscribes the receiver and `otherEndpoint` to each other, taking the current
// value of `otherEndpoint`.
//
// otherEndpoint - The endpoint to subscribe to, and to subscribe to the
//                 receiver. The receiver will take the current value from this
//                 endpoint. This argument must not be nil.
//
// Returns a disposable which can be used to cancel the mutual subscription.
- (RACDisposable *)bindFromEndpoint:(RACBindingEndpoint *)otherEndpoint;

- (id)init __attribute__((unavailable("Instantiate a RACBinding instead")));

@end
