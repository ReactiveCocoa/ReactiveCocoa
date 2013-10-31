//
//  RACAction+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"

@interface RACAction ()

// Initializes an action that will subscribe to `signal` for each execution.
//
// signal - A cold signal to subscribe to when the action is executed. This must
//          not be nil.
- (id)initWithSignal:(RACSignal *)signal;

@end
