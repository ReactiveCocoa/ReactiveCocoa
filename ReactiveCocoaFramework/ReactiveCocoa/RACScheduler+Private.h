//
//  RACScheduler+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/29/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// The thread-specific current scheduler key.
extern NSString * const RACSchedulerCurrentSchedulerKey;

// A private interface for internal RAC use only.
@interface RACScheduler ()

/// Initializes the receiver with the given name.
///
/// name - The name of the scheduler. If nil, a default name will be used.
///
/// Returns the initialized object.
- (id)initWithName:(NSString *)name;

@end
