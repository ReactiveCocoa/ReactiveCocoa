//
//  RACTestExampleScheduler.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 6/7/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveObjC/ReactiveObjC.h>

@interface RACTestExampleScheduler : RACQueueScheduler

- (id)initWithQueue:(dispatch_queue_t)queue;

@end
