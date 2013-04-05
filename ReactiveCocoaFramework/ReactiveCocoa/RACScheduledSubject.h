//
//  RACScheduledSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACSubject.h>

@class RACScheduler;

// A subject whose events will always be scheduled on the given scheduler.
@interface RACScheduledSubject : RACSubject

// Initializes the receiver with the given scheduler.
//
// scheduler - The scheduler on which all events should be scheduled. Cannot be
//             nil.
//
// Returns the initialized object.
- (id)initWithScheduler:(RACScheduler *)scheduler;

@end
