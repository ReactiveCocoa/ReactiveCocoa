//
//  RACBinding+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

@interface RACBinding ()

// Designated initializer.
//
// signal     - The binding will behave like this signal towards its
//              subscribers.
// subscriber - The binding will behave like this subscriber towards the signals
//              it's subscribed to.
- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@end
