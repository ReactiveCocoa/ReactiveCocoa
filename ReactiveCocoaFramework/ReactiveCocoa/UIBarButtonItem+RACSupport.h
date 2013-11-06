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

@interface UIBarButtonItem (RACSupport)

/// Sets the button's target and action using a `RACAction`.
///
/// Whenever the button is tapped, the -execute: method of the set action
/// will be invoked.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIBarButtonItem (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
