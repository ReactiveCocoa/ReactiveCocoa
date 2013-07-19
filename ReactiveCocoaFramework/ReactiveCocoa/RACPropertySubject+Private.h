//
//  RACPropertySubject+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 31/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"

@interface RACPropertySubject ()

// Designated initializer.
//
// signal     - The property will behave like this signal towards its
//              subscribers.
// subscriber - The property will behave like this subscriber towards the
//              signals it's subscribed to.
- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@end
