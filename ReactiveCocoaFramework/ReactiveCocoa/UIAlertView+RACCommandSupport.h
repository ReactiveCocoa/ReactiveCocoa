//
//  UIAlertView+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Henrik Hodne on 6/16/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACCommand;

@interface UIAlertView (RACCommandSupport)

// Sets the button's command. When the button is clicked, the command is
// executed with the index of the button pressed.
@property (nonatomic, strong) RACCommand *rac_command;

@end
