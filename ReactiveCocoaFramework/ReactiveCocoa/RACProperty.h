//
//  RACProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"
@class RACDisposable, RACBinding;

// A signal / subscriber interface to a property.
//
// Send values to it to update it's value. Subscribers are sent the current
// value on subscription, and new values as the property changes.
@interface RACProperty : RACSignal <RACSubscriber>

// Returns a new property with a starting value of `nil`.
+ (instancetype)property;

// Returns a new binding to the property.
- (RACBinding *)binding;

@end
