//
//  NSControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RACDeprecated.h"

@class RACCommand;
@class RACSignal;

@interface NSControl (RACSupport)

/// Sends the receiver whenever the control's action is invoked.
///
/// **Note:** Subscribing to this signal will reset the control's target and
/// action.
@property (nonatomic, strong, readonly) RACSignal *rac_actionSignal;

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

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_actionSignal` and `rac_enabled` instead");

@end
