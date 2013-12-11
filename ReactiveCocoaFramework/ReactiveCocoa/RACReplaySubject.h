//
//  RACReplaySubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSubject.h"

extern const NSUInteger RACReplaySubjectUnlimitedCapacity;

RACDeprecated("Use a plain RACSignal or RACSubject instead")
@interface RACReplaySubject : RACSubject

+ (instancetype)replaySubjectWithCapacity:(NSUInteger)capacity;

@end
