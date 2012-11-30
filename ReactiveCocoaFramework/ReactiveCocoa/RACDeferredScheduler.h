//
//  RACDeferredScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A scheduler that executes blocks in the current scheduler, after any blocks
// already scheduled have completed. If the current scheduler cannot be
// determined, it uses the main queue scheduler.
@interface RACDeferredScheduler : RACScheduler

@end
