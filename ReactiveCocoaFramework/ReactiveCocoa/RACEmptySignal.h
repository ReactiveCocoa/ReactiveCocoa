//
//  RACEmptySignal.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"

// A private `RACSignal` subclasses that synchronously sends completed to any
// subscribers.
@interface RACEmptySignal : RACSignal

+ (RACSignal *)empty;

@end
