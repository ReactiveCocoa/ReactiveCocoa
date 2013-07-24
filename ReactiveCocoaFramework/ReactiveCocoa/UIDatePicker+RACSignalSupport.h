//
//  UIDatePicker+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACBinding;

@interface UIDatePicker (RACSignalSupport)

// Creates and returns a RACBinding that sends the receiver's current date on
// subscription and whenever it changes, and sets the date to the values
// it receives. If it receives `nil`, it sets the date to `nilValue` instead.
- (RACBinding *)rac_dateBindingWithNilValue:(id)nilValue;

@end
