//
//  RACProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"
@class RACDisposable, RACBinding;

// A RACProperty subject saves the last value sent to it and resends it to
// new subscribers. It will also resend error or completion.
//
// Values sent to a RACProperty are also sent to it's bindings' subscribers.
// Values sent to a RACProperty's bindings are also sent to the RACProperty.
@interface RACProperty : RACSubject

// Returns a new RACProperty with a starting value of `nil`.
+ (instancetype)property;

// Returns a new binding of the RACProperty.
- (RACBinding *)binding;

@end
