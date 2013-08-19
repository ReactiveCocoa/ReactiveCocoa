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
//
// If you use this method, you **must** set the text view's `delegate` to nil before
// the text view itself is released. This can usually be done from the -dealloc
// method of the text view's owner (view or view controller).
- (RACSignal *)rac_signalForDelegateMethod:(SEL)method;

// Creates and returns a signal for the text of the field. It always starts with
// the current text.
- (RACSignal *)rac_textSignal;

@end
