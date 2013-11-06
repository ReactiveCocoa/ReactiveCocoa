//
//  RACSignalSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

@class RACSignal;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RACSignalSequence : RACSequence

+ (RACSequence *)sequenceWithSignal:(RACSignal *)signal;

@end

#pragma clang diagnostic pop
