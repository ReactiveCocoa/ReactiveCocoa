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

/// Sends the receiver whenever the control sends an action message.
///
/// **Note:** Subscribing to this signal will reset the control's target and
/// action. However, this signal can be used simultaneously with `rac_action`.
@property (nonatomic, strong, readonly) RACSignal *rac_actionSignal;

/// An action to execute whenever the control sends an action message.
///
/// The receiver will be automatically enabled and disabled based on
/// `RACAction.enabled`.
///
/// **Note:** Setting this property will reset the control's target and action.
/// However, this property can be used simultaneously with `rac_actionSignal`.
@property (nonatomic, strong) RACAction *rac_action;

/// For a text-based control, sends the current string value of the receiver,
/// then the new values any time it changes.
///
/// Using this method on a control without editable text is considered undefined
/// behavior.
@property (nonatomic, strong, readonly) RACSignal *rac_textSignal;

/// Whether the receiver is enabled.
///
/// This property is mostly for the convenience of bindings (because -isEnabled
/// does not work in a key path), and may have `RAC()` applied to it, but it is
/// not KVO-compliant.
@property (nonatomic, assign, getter = rac_isEnabled) BOOL rac_enabled;

@end

@interface NSControl (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
