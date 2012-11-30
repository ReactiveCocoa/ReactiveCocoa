//
//  RACScheduler+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/29/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

extern const void * RACSchedulerCurrentSchedulerKey;

@interface RACScheduler ()

// A dedicated scheduler for new subscriptions used to ensure that subscription
// happens on a known scheduler. If the current scheduler can be determined,
// schedule blocks are immediately performed. If not, blocks are scheduled with
// the +mainQueueScheduler.
+ (instancetype)subscriptionScheduler;

// Initializes the receiver with the given name.
//
// name - The name of the scheduler. If nil, a default name will be used.
//
// Returns the initialized object.
- (id)initWithName:(NSString *)name;

@end
