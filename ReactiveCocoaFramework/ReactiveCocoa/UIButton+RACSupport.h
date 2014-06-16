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

/// An action to execute whenever the button is tapped.
///
/// The receiver will be automatically enabled and disabled based on
/// `RACAction.enabled`.
@property (nonatomic, strong) RACAction *rac_action;

@end

@interface UIButton (RACSupportDeprecated)

@property (nonatomic, strong) RACCommand *rac_command RACDeprecated("Use `rac_action` instead");

@end
