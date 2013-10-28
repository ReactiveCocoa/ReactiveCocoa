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
//
// signal    - The signal which will perform the work of the promise. This must
//             not be nil.
// scheduler - The scheduler to subscribe to `signal` upon. Use
//             +immediateScheduler to subscribe as quickly as possible. This
//             must not be nil.
- (id)initWithSignal:(RACSignal *)signal scheduler:(RACScheduler *)scheduler;

@end
