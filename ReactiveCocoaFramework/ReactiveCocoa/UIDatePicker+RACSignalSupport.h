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

/// Creates a new RACChannel-based binding to the receiver.
///
/// nilValue - The date to set when the terminal receives `nil`.
///
/// Returns a RACChannelTerminal that sends the receiver's date whenever the
/// UIControlEventValueChanged control event is fired, and sets the date to the
/// values it receives.
- (RACChannelTerminal *)rac_newDateChannelWithNilValue:(NSDate *)nilValue;

@end
