//
//  RACErrorSignal.h
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-10-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"

// A private `RACSignal` subclasses that synchronously sends an error to any
// subscribers.
@interface RACErrorSignal : RACSignal

+ (RACSignal *)error:(NSError *)error;

@end
