//
//  RACBinding+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

@interface RACBinding ()

// The binding will behave like this signal towards its subscribers.
//
// This property should be set before any subscriptions are set up and should
// not be changed afterwards to avoid race conditions.
@property (nonatomic, strong) RACSignal *signal;

// The binding will behave like this subscriber towards the signals it's
// subscribed to.
//
// This property should be set before any subscriptions are set up and should
// not be changed afterwards to avoid race conditions.
@property (nonatomic, strong) id<RACSubscriber> subscriber;

@end
