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

// A signal / subscriber interface to a property. Send values to it to set new
// values. Subscribe to it to receive the property's current value and
// subsequent values.
@interface RACProperty : RACSignal <RACSubscriber>

// Returns a new property
+ (instancetype)property;

// Returns a new binding to the property.
- (RACBinding *)binding;

@end
