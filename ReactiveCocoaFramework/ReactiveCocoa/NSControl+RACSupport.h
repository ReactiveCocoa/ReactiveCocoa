//
//  NSControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACCommand;
@class RACSignal;

@interface NSControl (RACSupport)

/// Sets the control's command. When the control is clicked, the command is
/// executed with the sender of the event. The control's enabledness is bound
/// to the command's `canExecute`.
///
/// Note: this will reset the control's target and action.
@property (nonatomic, strong) RACCommand *rac_command;

/// Observes a text-based control for changes.
///
/// Using this method on a control without editable text is considered undefined
/// behavior.
///
/// Returns a signal which sends the current string value of the receiver, then
/// the new value any time it changes.
- (RACSignal *)rac_textSignal;

@end
