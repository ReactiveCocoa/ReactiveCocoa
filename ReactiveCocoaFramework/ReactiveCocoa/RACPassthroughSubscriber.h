//
//  RACPassthroughSubscriber.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/RACSubscriber.h>

// Passes through all events to another subscriber while not disposed.
@interface RACPassthroughSubscriber : NSObject <RACSubscriber>

// Initializes the receiver to pass through events until disposed.
//
// subscriber - The subscriber to forward events to. This must not be nil.
// disposable - When this disposable is disposed, no more events will be
//              forwarded. This must not be nil.
//
// Returns an initialized passthrough subscriber.
- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber disposable:(RACDisposable *)disposable;

@end
