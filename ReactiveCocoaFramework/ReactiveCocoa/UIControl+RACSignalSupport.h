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
// key path on subscription and whenever one of the control events is triggered
// and sets the value of the key path to the values it receives. If it receives
// `nil`, it sets the value to `nilValue` instead.
//
// Note that this differs from other RACBindings as it will not react to changes
// triggered from code regardless of what triggered the changes.
- (RACBinding *)rac_bindingForControlEvents:(UIControlEvents)controlEvents keyPath:(NSString *)keyPath nilValue:(id)nilValue;

@end
