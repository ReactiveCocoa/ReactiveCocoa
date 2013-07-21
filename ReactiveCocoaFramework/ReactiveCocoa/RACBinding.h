//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"

@class RACSignal;

// An abstract class representing one side of a two-way binding.
//
// This really isn't useful on its own. Use RACBindingFactsEndpoint or
// RACBindingRumorsEndpoint instead.
@interface RACBindingEndpoint : NSObject
@end

// An endpoint to be bound to the canonical version of the data (typically the
// model).
//
// This endpoint is meant to receive rumors (e.g., from the UI), process them,
// and determine new facts, if necessary. Whenever there are new facts, they
// should be sent on the `factsSubscriber` of this endpoint.
@interface RACBindingFactsEndpoint : RACBindingEndpoint

// A signal of rumors, which represent uncommitted changes to the data being
// bound (e.g., modifications made by the user).
//
// Subscribers to this signal will immediately receive the latest rumor (if any),
// and then all future rumors.
@property (nonatomic, strong, readonly) RACSignal *rumorsSignal;

// A subscriber to send updated facts on.
//
//  - `next` events sent to this subscriber will be forwarded to the
//    `factsSignal`.
//  - `error` or `completed` events sent to this subscriber will be forwarded
//    onto `factsSignal` and `rumorsSignal`.
@property (nonatomic, strong, readonly) id<RACSubscriber> factsSubscriber;

@end

// An endpoint to be bound to the modifiable version of the data (typically the
// UI).
//
// This endpoint is meant to receive facts (e.g., from the model) and present
// them for editing. Whenever edits are made, new rumors should be created and
// sent on the `rumorsSubscriber` of this endpoint.
@interface RACBindingRumorsEndpoint : RACBindingEndpoint

// A signal of facts, which represent the canonical version of the data being
// bound.
//
// Subscribers to this signal will immediately receive the latest fact (if any),
// and then all future facts.
@property (nonatomic, strong, readonly) RACSignal *factsSignal;

// A subscriber to send rumors to.
//
//  - `next` events sent to this subscriber will be forwarded onto `rumorsSignal`.
//  - `error` or `completed` events sent to this subscriber will be forwarded
//    onto `factsSignal` and `rumorsSignal`.
@property (nonatomic, strong, readonly) id<RACSubscriber> rumorsSubscriber;

@end

// A two-way binding, represented with RACBindingFactsEndpoint and
// RACBindingRumorsEndpoint.
//
//  - `next` events sent to one endpoint are sent to the subscribers of the
//    _other_ endpoint (but not those of the original endpoint).
//  - `error` or `completed` events sent to either endpoint will be sent to the
//    subscribers of both endpoints.
//
// The properties on this class use terminology from [Three principles for GUI
// elements with bidirectional data
// flow](http://apfelmus.nfshost.com/blog/2012/03/29-frp-three-principles-bidirectional-gui.html#composing-user-events).
@interface RACBinding : NSObject

// The endpoint which connects to the canonical version of the data being bound.
@property (nonatomic, strong, readonly) RACBindingFactsEndpoint *factsEndpoint;

// The endpoint which connects to the modifiable version of the data being
// bound.
@property (nonatomic, strong, readonly) RACBindingRumorsEndpoint *rumorsEndpoint;

@end
