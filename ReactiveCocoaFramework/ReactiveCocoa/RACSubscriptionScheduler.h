//
//  RACSubscriptionScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A scheduler that fills two requirements:
//
//   1. By the time subscription happens, we need a valid +currentScheduler.
//   2. Subscription should happen as soon as possible.
//
// To fulfill those two, if we already have a valid +currentScheduler, it
// immediately executes scheduled blocks. If we don't, it will execute scheduled
// blocks with +mainThreadScheduler.
@interface RACSubscriptionScheduler : RACScheduler

@end
