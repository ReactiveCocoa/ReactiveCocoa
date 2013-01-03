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

// A binding of a RACProperty.
//
// Values sent to the binding are only sent to the binding's property and it's
// other bindings's subscribers, not to the binding's subscribers. Values sent
// to a property are sent to all it's bindings' subscribers.
@interface RACBinding : RACSignal <RACSubscriber>

// Binds the receiver to `binding` by subscribing each one to the other's
// changes.
//
// Returns a disposable that can be used to stop the binding.
- (RACDisposable *)bindTo:(RACBinding *)binding;

@end
