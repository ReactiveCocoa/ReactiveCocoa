//
//  NSControl+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACCommand, RACSignal;

@interface NSControl (RACCommandSupport)

/// Sets the control's command. When the control is clicked, the command is
/// executed with the sender of the event. The control's enabledness is bound
/// to the command's `canExecute`.
///
/// Note: this will reset the control's target and action.
@property (nonatomic, strong) RACCommand *rac_command;

/// Substitute another signal for the control's `enabled` value binding.
- (void)rac_rebindEnabled:(RACSignal *)enabledSignal;

@end
