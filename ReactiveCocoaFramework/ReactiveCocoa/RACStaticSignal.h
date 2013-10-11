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

// Sends completed to any subscribers.
+ (RACSignal *)empty;

// Sends an error to any subscribers.
+ (RACSignal *)error:(NSError *)error;

// Sends a value to any subscribers, then completes.
+ (RACSignal *)return:(id)value;

// Never sends anything to a subscriber.
+ (RACSignal *)never;

// Defer creation of a signal, then send all of its events.
+ (RACSignal *)defer:(RACSignal * (^)(void))block;

@end
