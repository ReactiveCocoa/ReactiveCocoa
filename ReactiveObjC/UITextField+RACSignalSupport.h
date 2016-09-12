//
//  UITextField+RACSignalSupport.h
//  ReactiveObjC
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;
@class RACSignal;

@interface UITextField (RACSignalSupport)

/// Creates and returns a signal for the text of the field. It always starts with
/// the current text. The signal sends next when the UIControlEventAllEditingEvents
/// control event is fired on the control.
- (RACSignal *)rac_textSignal;

/// Creates a new RACChannel-based binding to the receiver.
///
/// Returns a RACChannelTerminal that sends the receiver's text whenever the
/// UIControlEventAllEditingEvents control event is fired, and sets the text
/// to the values it receives.
- (RACChannelTerminal *)rac_newTextChannel;

@end
