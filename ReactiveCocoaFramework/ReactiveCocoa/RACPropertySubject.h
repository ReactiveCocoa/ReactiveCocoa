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
// Values sent to a RACPropertySubject are also sent to it's bindings'
// subscribers. Values sent to a RACProperty's bindings are also sent to the
// RACPropertySubject.
@interface RACPropertySubject : RACSubject

// Returns a new RACPropertySubject with a starting value of `nil`.
+ (instancetype)property;

// Returns a new binding of the RACPropertySubject.
- (RACBinding *)binding;

@end
