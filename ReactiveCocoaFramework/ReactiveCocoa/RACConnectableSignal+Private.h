//
//  RACConnectableSignal+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSignal.h"

@class RACSubject;

@interface RACConnectableSignal ()

+ (instancetype)connectableSignalWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject;

@end
