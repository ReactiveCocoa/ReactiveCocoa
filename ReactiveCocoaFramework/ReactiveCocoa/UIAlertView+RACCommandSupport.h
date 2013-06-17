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

// A command that's executed when a button on the alert view is pressed.
// The command is executed with an `NSNumber` containing the index of the
// button that was pressed (see
// `-[UIAlertViewDelegate alertView:clickedButtonAtIndex:]`).
//
// Note: This will override the alert view's delegate, so you can't use this
// together with a custom delegate.
@property (nonatomic, strong) RACCommand *rac_command;

@end
