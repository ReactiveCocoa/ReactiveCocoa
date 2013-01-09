//
//  RACBinding+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

@interface RACBinding ()

// Designated initializer.
//
// signal     - A signal of `RACTuple`s where the first element is the value of
//              the binding's property as it changes, and the second element is
//              the `RACBinding` that triggered the change, or `nil` if the
//              change was triggered by other means. The signal must also send a
//              `RACTuple` with the current value and it's originator on
//              subscription.
// subscriber - A subscriber that will be sent a `RACTuple` every time the
//              binding's property is changed. The first element will be the new
//              value, the second element will be the `RACBinding` that
//              triggered the change or nil if the change was triggered by the
//              property itself.
- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@end
