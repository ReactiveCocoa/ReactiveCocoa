//
//  UIRefreshControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACDeprecated.h"

@class RACAction;
@class RACCommand;

@interface UIRefreshControl (RACSupport)

/// An action to execute when the refresh control is activated.
///
/// The receiver will be automatically enabled and disabled based on
/// `RACAction.enabled`.
///
/// When the action finishes executing (and if it was started by the receiver),
/// -endRefreshing will be invoked automatically.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIRefreshControl (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
