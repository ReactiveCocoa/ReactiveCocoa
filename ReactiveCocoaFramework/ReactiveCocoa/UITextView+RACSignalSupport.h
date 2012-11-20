//
//  UITextView+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UITextView (RACSignalSupport)

// Creates and returns a signal that sends the sender of the delegate method
// whenever it is triggered.
- (RACSignal *)rac_signalForDelegateMethod:(SEL)method;

// Creates and returns a signal for the text of the field. It always starts with
// the current text.
- (RACSignal *)rac_textSignal;

@end
