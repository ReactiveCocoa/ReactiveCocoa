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

// A signal / subscriber interface to a property. Send values to it to set new
// values. Subscribe to it to receive the property's current value and
// subsequent values that weren't set by the same binding.
@interface RACBinding : RACSignal <RACSubscriber>

// Binds the receiver to `binding` by subscribing each one to the other's
// changes.
//
// Returns a disposable that can be used to stop the binding.
- (RACDisposable *)bindTo:(RACBinding *)binding;

@end
