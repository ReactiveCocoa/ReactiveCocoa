//
//  RACImmediateScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

// A private scheduler which immediately executes its scheduled blocks.
@interface RACImmediateScheduler : RACScheduler

@end
