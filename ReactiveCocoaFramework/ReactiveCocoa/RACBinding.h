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
//         View         ------>       Model
//  `followingEndpoint` <------ `leadingEndpoint`
//
// The initial value of the model and all future changes to it are _sent on_ the
// `leadingEndpoint`, and _received from_ the `followingEndpoint`.
//
// Likewise, whenever the user changes the value of the view, that value is sent
// on the `followingEndpoint`, and received in the model from the
// `leadingEndpoint`. However, the initial value of the view is not received
// from the `leadingEndpoint` (only future changes).
@interface RACBinding : NSObject

// The endpoint which "leads" the binding, by sending its latest value
// immediately to new subscribers of the `followingEndpoint`.
//
// New subscribers to this endpoint will not receive a starting value.
@property (nonatomic, strong, readonly) RACBindingEndpoint *leadingEndpoint;

// The endpoint which "follows" the lead of the other endpoint.
//
// The latest value sent to the `leadingEndpoint` (if any) will be sent
// immediately to new subscribers of this endpoint.
@property (nonatomic, strong, readonly) RACBindingEndpoint *followingEndpoint;

@end

// Represents one end of a RACBinding.
//
// An endpoint is similar to a socket or pipe -- it represents one end of
// a connection (the RACBinding, in this case). Values sent to this endpoint
// will _not_ be received by its subscribers. Instead, the values will be sent
// to the subscribers of the RACBinding's _other_ endpoint.
//
// For example, when using the `followingEndpoint`, _sent_ values can only be
// _received_ from the `leadingEndpoint`, and vice versa.
//
// To make it easy to terminate a RACBinding, `error` and `completed` events
// sent to either endpoint will be received by the subscribers of _both_
// endpoints.
//
// Do not instantiate this class directly. Create a RACBinding instead.
@interface RACBindingEndpoint : RACSignal <RACSubscriber>

- (id)init __attribute__((unavailable("Instantiate a RACBinding instead")));

@end
