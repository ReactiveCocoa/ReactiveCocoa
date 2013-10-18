//
//  RACPromise+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPromise.h"

@interface RACPromise ()

// Initializes a promise that will subscribe to `signal` to start work.
- (id)initWithSignal:(RACSignal *)signal;

@end
