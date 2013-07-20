//
//  UISlider+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACBinding;

@interface UISlider (RACSignalSupport)

// Creates and returns a RACBinding that sends the receiver's current value on
// subscription and whenever UIControlEventValueChanged is fired, and sets the
// value to the values it receives. If it receives `nil`, it sets the value to
// `nilValue` instead.
//
// Note that this differs from other RACBindings as it will not react to changes
// triggered from code regardless of what triggered the changes.
- (RACBinding *)rac_valueBindingWithNilValue:(id)nilValue;

@end
