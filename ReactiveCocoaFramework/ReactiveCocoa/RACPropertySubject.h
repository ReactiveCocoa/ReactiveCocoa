//
//  RACPropertySubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"

@class RACDisposable, RACBinding;

// A RACPropertySubject saves the last value sent to it and resends it to new
// subscribers. It will also resend error or completion.
//
// `next` and `completed` events sent to a RACPropertySubject are also sent to
// its bindings' subscribers. `next` and `completed` events sent to
// a RACPropertySubject's bindings are also sent to the RACPropertySubject.
//
// It is considered undefined behavior to send `error` to
// a RACPropertySubject or its bindings.
@interface RACPropertySubject : RACSubject

// Returns a new RACPropertySubject with a starting value of `nil`.
+ (instancetype)property;

// Returns a new binding of the RACPropertySubject.
- (RACBinding *)binding;

@end
