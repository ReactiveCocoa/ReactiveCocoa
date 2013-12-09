//
//  UIBarButtonItem+RACSupport.h
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 3/27/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACDeprecated.h"

@class RACCommand;
@class RACSignal;

@interface UIBarButtonItem (RACSupport)

/// Sends the receiver whenever the item's action is invoked.
///
/// **Note:** Subscribing to this signal will reset the item's target and
/// action.
@property (nonatomic, strong, readonly) RACSignal *rac_actionSignal;

@end

@interface UIBarButtonItem (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_actionSignal` and bind to `enabled` instead");

@end
