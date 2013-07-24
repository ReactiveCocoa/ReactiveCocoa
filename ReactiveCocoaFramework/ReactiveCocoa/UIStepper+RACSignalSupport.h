//
//  UIStepper+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACBinding;

@interface UIStepper (RACSignalSupport)

// Creates and returns a RACBinding that sends the receiver's current value on
// subscription and whenever it changes, and sets the value to the values it
// receives. If it receives `nil`, it sets the value to `nilValue` instead.
- (RACBinding *)rac_valueBindingWithNilValue:(id)nilValue;

@end
