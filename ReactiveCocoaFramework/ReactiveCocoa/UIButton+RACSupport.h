//
//  UIButton+RACSupport.h
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACDeprecated.h"

@class RACAction;
@class RACCommand;

@interface UIButton (RACSupport)

/// Sets the button's target and action using a `RACAction`.
///
/// Whenever the button is tapped, the -execute: method of the set action
/// will be invoked.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIButton (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
