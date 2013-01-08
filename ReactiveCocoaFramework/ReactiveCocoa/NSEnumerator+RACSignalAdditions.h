//
//  NSEnumerator+RACSignalAdditions.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal, RACScheduler;

@interface NSEnumerator (RACSignalAdditions)

// Invokes -rac_signalWithScheduler: with a new RACScheduler.
- (RACSignal *)rac_signal;

// Creates and returns a signal that sends each object in the receiver to it's
// first subscriber, then completes. Subsequent subscribers will immediately
// receive `completed`.
//
// Each object is sent in its own scheduled block, such that control of the
// scheduler is yielded between each value.
//
// The enumerator is gradually exhausted as the values are sent.
- (RACSignal *)rac_signalWithScheduler:(RACScheduler *)scheduler;

@end
