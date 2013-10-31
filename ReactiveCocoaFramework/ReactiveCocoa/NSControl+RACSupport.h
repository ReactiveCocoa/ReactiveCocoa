//
//  NSControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RACDeprecated.h"

@class RACAction;
@class RACCommand;
@class RACSignal;

@interface NSControl (RACSupport)

/// Sets the control's target and action using a `RACAction`.
@property (nonatomic, strong) RACAction *rac_action;

/// Enables/disables the receiver based on the BOOLs sent from a signal.
@property (nonatomic, strong) RACSignal *rac_enabled;

/// Observes a text-based control for changes.
///
/// Using this method on a control without editable text is considered undefined
/// behavior.
///
/// Returns a signal which sends the current string value of the receiver, then
/// the new value any time it changes.
- (RACSignal *)rac_textSignal;

@end

@interface NSControl (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use -rac_action and -rac_enabled instead");

@end
