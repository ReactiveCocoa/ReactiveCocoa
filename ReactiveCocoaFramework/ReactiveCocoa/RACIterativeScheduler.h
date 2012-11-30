//
//  RACIterativeScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A schedule that executes scheduled blocks immediately, or if called within
// another scheduled block, enqueues the blocks to be performed after the
// current block ends.
@interface RACIterativeScheduler : RACScheduler

@end
