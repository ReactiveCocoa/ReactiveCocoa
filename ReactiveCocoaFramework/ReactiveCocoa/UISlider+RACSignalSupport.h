//
//  UISlider+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;

@interface UISlider (RACSignalSupport)

// Creates and returns a RACChannelTerminal that sends the receiver's value
// whenever the UIControlEventValueChanged control event is fired, and sets the
// value to the values it receives. If it receives `nil`, it sets the value to
// `nilValue` instead.
- (RACChannelTerminal *)rac_valueChannelWithNilValue:(id)nilValue;

@end
