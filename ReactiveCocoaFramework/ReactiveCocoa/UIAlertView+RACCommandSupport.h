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

// Sets the alert view's command. When a button on the alert view is pressed,
// the command is executed with the index of the button that was pressed.
//
// This will override the alert view's delegate, so you can't use this together
// with a custom delegate.
@property (nonatomic, strong) RACCommand *rac_command;

@end
