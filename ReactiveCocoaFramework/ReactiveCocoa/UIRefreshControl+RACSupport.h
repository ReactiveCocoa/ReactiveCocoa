//
//  UIRefreshControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACAction;
@class RACCommand;

@interface UIRefreshControl (RACSupport)

/// An action to execute when the refresh control is activated.
///
/// When the action finishes executing (and if it was started by the receiver),
/// -endRefreshing will be invoked automatically.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIRefreshControl (RACSupportDeprecated)

/// Manipulate the RACCommand property associated with this refresh control.
///
/// When this refresh control is activated by the user, the command will be
/// executed. Upon completion or error of the execution signal, -endRefreshing
/// will be invoked.
@property (nonatomic, strong) RACCommand *rac_command;

@end
