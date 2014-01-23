//
//  UIBarButtonItem+RACSupport.h
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 3/27/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACDeprecated.h"

@class RACAction;
@class RACCommand;
@class RACSignal;

@interface UIBarButtonItem (RACSupport)

/// Sends the receiver whenever the item sends an action message.
///
/// **Note:** Subscribing to this signal will reset the item's target and
/// action. However, this signal can be used simultaneously with `rac_action`.
@property (nonatomic, strong, readonly) RACSignal *rac_actionSignal;

/// An action to execute whenever the item sends an action message.
///
/// The receiver will be automatically enabled and disabled based on
/// `RACAction.enabled`.
///
/// **Note:** Setting this property will reset the item's target and action.
/// However, this property can be used simultaneously with `rac_actionSignal`.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIBarButtonItem (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
