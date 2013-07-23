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
// Conceptually, RACBinding can be thought of as two controllable signals that
// work in parallel. "Facts" represent the authoritative source of data, while
// "rumors" represent less authoritative versions of, or changes to, that data.
//
// For example, when binding between a view and a model:
//
//         View         ------> rumors ------>       Model
//  `endpointForRumors` <------ facts  <------ `endpointForFacts`
//
// Whenever the model changes, it has a new "fact" for the view to use. That
// value is _sent on_ the `endpointForFacts`, and _received from_ the
// `endpointForRumors`.
//
// Likewise, whenever the user changes the value of the view, a new "rumor" is
// generated. That value is sent on the `endpointForRumors`, and received by the
// model from the `endpointForFacts`.
//
// The properties on this class use terminology from [Three principles for GUI
// elements with bidirectional data
// flow](http://apfelmus.nfshost.com/blog/2012/03/29-frp-three-principles-bidirectional-gui.html#composing-user-events).
@interface RACBinding : NSObject

// The endpoint which should be bound to the source of "facts", which represent
// the canonical version of the data being bound.
//
// **Send facts** to this endpoint. Subscribe to this endpoint to **receive
// rumors**. The latest rumor (if any) will be sent immediately upon
// subscription.
@property (nonatomic, strong, readonly) RACBindingEndpoint *endpointForFacts;

// The endpoint which should be bound to the source of "rumors", which represent
// uncommitted changes to the data being bound (e.g., modifications made by the
// user).
//
// **Send rumors** to this endpoint. Subscribe to this endpoint to **receive
// facts**. The latest fact (if any) will be sent immediately upon subscription.
@property (nonatomic, strong, readonly) RACBindingEndpoint *endpointForRumors;

@end

// Represents one end of a RACBinding.
//
// An endpoint is similar to a socket or pipe -- it represents one end of
// a connection (the RACBinding, in this case). Values sent to this endpoint
// will _not_ be received by its subscribers. Instead, the values will be sent
// to the subscribers of the RACBinding's _other_ endpoint.
//
// For example, when using the `endpointForFacts`, _sent_ values can only be
// _received_ from the `endpointForRumors`, and vice versa.
//
// To make it easy to terminate a RACBinding, `error` and `completed` events
// sent to either endpoint will be received by the subscribers of _both_
// endpoints.
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

@end
