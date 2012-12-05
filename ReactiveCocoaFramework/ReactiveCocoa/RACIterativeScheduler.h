//
//  RACIterativeScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A scheduler that flattens and defers recursion. See +[RACScheduler
// iterativeScheduler] for more information.
@interface RACIterativeScheduler : RACScheduler
@end
