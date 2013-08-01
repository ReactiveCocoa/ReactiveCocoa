//
//  UIDatePicker+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;

@interface UIDatePicker (RACSignalSupport)

// Creates and returns a RACChannelTerminal that sends the receiver's date
// whenever the UIControlEventValueChanged control event is fired, and sets the
// date to the values it receives. If it receives `nil`, it sets the date to
// `nilValue` instead.
- (RACChannelTerminal *)rac_dateChannelWithNilValue:(id)nilValue;

@end
