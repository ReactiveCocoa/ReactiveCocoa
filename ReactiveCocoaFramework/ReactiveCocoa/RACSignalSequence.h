//
//  RACSignalSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

@class RACSignal;

/// Private class that adapts a RACSignal to the RACSequence interface.
@interface RACSignalSequence : RACSequence

/// Returns a sequence for enumerating over the given signal.
+ (RACSequence *)sequenceWithSignal:(RACSignal *)signal;

@end
