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
///
/// Whenever the control is activated, the -execute: method of the set action
/// will be invoked.
@property (nonatomic, strong) RACAction *rac_action;

/// Whether the receiver is enabled.
///
/// This property is mostly for the convenience of bindings (because -isEnabled
/// does not work in a key path), and may have `RAC()` applied to it, but it is
/// not KVO-compliant.
@property (nonatomic, assign, getter = rac_isEnabled) BOOL rac_enabled;

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

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` and `rac_enabled` instead");

@end
