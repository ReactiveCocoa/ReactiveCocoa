//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"
@class RACDisposable;

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
