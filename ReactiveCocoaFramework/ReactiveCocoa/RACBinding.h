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

// A binding of a RACPropertySubject.
//
// Values sent to the binding are sent to the binding's RACPropertySubject's
// subscribers and subscribers of other RACBindings of the same property
// subject, but are not sent to the receiver's subscribers. A binding's
// subscribers will also receive values sent to the binding's property subject.
@interface RACBinding : RACSignal <RACSubscriber>

// Binds the receiver to `binding` by subscribing each one to the other's
// changes.
//
// When called, `binding`s current value will be sent to the receiver and the
// receiver's current value will be discarded.
//
// Returns a disposable that can be used to stop the binding.
- (RACDisposable *)bindTo:(RACBinding *)binding;

@end
