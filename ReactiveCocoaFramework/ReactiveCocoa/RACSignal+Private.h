//
//  RACSignal+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"

@class RACLiveSubscriber;

@interface RACSignal ()

/// Add the given subscriber to the receiver, triggering any side effects
/// associated with subscription.
///
/// This method should be overridden instead of -subscribe: or -subscribeNext:…,
/// etc.
///
/// subscriber - The subscriber to attach to the receiver. This must not be
///              nil, and will already have the receiver set as its `signal`.
- (void)attachSubscriber:(RACLiveSubscriber *)subscriber;

@end
