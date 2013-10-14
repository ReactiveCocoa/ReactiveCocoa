//
//  RACDynamicSignal.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

// A private `RACSignal` subclass that implements its subscription behavior
// using a block.
@interface RACDynamicSignal : RACSignal

+ (RACSignal *)generator:(RACSignalStepBlock (^)(id<RACSubscriber> subscriber, RACCompoundDisposable *disposable))generatorBlock;

@end
