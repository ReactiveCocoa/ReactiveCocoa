//
//  RACDeferredScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A scheduler that executes blocks in +currentScheduler, after any blocks
// already scheduled have completed. If +currentScheduler is nil, it uses
// +mainThreadScheduler.
@interface RACDeferredScheduler : RACScheduler

@end
