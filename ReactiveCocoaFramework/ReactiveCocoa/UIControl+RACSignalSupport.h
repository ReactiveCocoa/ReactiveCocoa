//
//  UIControl+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal, RACBinding;

@interface UIControl (RACSignalSupport)

// Creates and returns a signal that sends the sender of the control event
// whenever one of the control events is triggered.
- (RACSignal *)rac_signalForControlEvents:(UIControlEvents)controlEvents;

// Creates and returns a RACBinding that sends the current value of the given
// key on subscription and whenever one of the control events is triggered and
// sets the value of the key to the values it receives. If it receives `nil`, it
// sets the value to `nilValue` instead.
//
// controlEvents - A mask of UIControlEvents on which to send new values.
// key           - The key whose value should be read and written respectively
//                 on subscription and when a control event fires, and when a
//                 value is sent to the RACBinding.
// primitive     - Whether the key refers to a primitive (non-object) property.
// nilValue      - The value to be assigned to the key when `nil` is sent to the
//                 RACBinding.
//
// Note that this differs from other RACBindings as it will not react to changes
// triggered from code regardless of what triggered the changes.
- (RACBinding *)rac_bindingForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key primitive:(BOOL)primitive nilValue:(id)nilValue;

@end
