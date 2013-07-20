//
//  UITextField+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal, RACBinding;

@interface UITextField (RACSignalSupport)

// Creates and returns a signal for the text of the field. It always starts with
// the current text. The signal sends next when the UIControlEventEditingChanged
// control event is fired on the control.
- (RACSignal *)rac_textSignal;

// Creates and returns a RACBinding that sends the receiver's current text on
// subscription and whenever UIControlEventEditingChanged is fired and sets the
// text to the values it receives. If it receives `nil`, it sets the text to
// `nilValue` instead.
//
// Note that this differs from other RACBindings as it will not react to changes
// triggered from code regardless of what triggered the changes.
- (RACBinding *)rac_textBindingWithNilValue:(id)nilValue;

@end
