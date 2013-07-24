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
// key on subscription, whenever one of the control events is triggered and
// whenever a KVO notification for the key is triggered. The RACBinding sets the
// value of the key to the values it receives. If it receives `nil`, it sets the
// value to `nilValue` instead.
//
// controlEvents - A mask of UIControlEvents on which to send new values.
// key           - The key whose value should be read and written respectively
//                 on subscription and when a control event or KVO notification
//                 fires, and when a value is sent to the RACBinding.
// nilValue      - The value to be assigned to the key when `nil` is sent to the
//                 RACBinding.
- (RACBinding *)rac_bindingForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key nilValue:(id)nilValue;

@end
