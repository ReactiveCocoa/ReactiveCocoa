//
//  RACStaticSignal.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-11.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"

// A private `RACSignal` subclass that synchronously sends premeditated events
// to subscribers.
@interface RACStaticSignal : RACSignal

- (instancetype)initWithSubscriptionBlock:(void (^)(id<RACSubscriber> subscriber))block;

@end
