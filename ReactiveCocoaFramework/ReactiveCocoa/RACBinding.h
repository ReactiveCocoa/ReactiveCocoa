//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"

@class RACSignal;

// A two-way binding.
//
// The properties on this class use terminology from [Three principles for GUI
// elements with bidirectional data
// flow](http://apfelmus.nfshost.com/blog/2012/03/29-frp-three-principles-bidirectional-gui.html#composing-user-events).
@interface RACBinding : NSObject

// A signal of facts, which represent the canonical version of the data being
// bound.
//
// Subscribers to this signal will immediately receive the latest fact (if any),
// and then all future facts.
@property (nonatomic, strong, readonly) RACSignal *factsSignal;

// A subscriber to send updated facts on.
//
//  - `next` events sent to this subscriber will be forwarded to the
//    `factsSignal`.
//  - `error` or `completed` events sent to this subscriber will be forwarded
//    onto `factsSignal` and `rumorsSignal`.
@property (nonatomic, strong, readonly) id<RACSubscriber> factsSubscriber;

// A signal of rumors, which represent uncommitted changes to the data being
// bound (e.g., modifications made by the user).
//
// Subscribers to this signal will immediately receive the latest rumor (if any),
// and then all future rumors.
@property (nonatomic, strong, readonly) RACSignal *rumorsSignal;

// A subscriber to send rumors to.
//
//  - `next` events sent to this subscriber will be forwarded onto `rumorsSignal`.
//  - `error` or `completed` events sent to this subscriber will be forwarded
//    onto `factsSignal` and `rumorsSignal`.
@property (nonatomic, strong, readonly) id<RACSubscriber> rumorsSubscriber;

@end
