//
//  UITextField+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UITextField (RACSignalSupport)

// Creates and returns a signal that sends the sender of the delegate method
// whenever it is triggered.
- (RACSignal *)rac_signalForDelegateMethod:(SEL)method;

// Creates and returns a signal for the text of the field. It always starts with
// the current text. The signal sends next when the UIControlEventEditingChanged
// control event is fired on the control.
- (RACSignal *)rac_textSignal;

@end
