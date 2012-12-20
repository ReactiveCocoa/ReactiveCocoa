//
//  RACCancelableSignal+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCancelableSignal.h"

@interface RACCancelableSignal ()

// Defaults to using a RACReplaySubject.
+ (instancetype)cancelableSignalSourceSignal:(RACSignal *)sourceSignal withBlock:(void (^)(void))block;
+ (instancetype)cancelableSignalSourceSignal:(RACSignal *)sourceSignal subject:(RACSubject *)subject withBlock:(void (^)(void))block;

@end
