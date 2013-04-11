//
//  UIBarButtonItem+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 3/27/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACCommand;

@interface UIBarButtonItem (RACCommandSupport)

// Sets the control's command. When the control is clicked, the command is
// executed with the sender of the event. The control's enabledness is bound
// to the command's `canExecute`.
//
// Note: this will reset the control's target and action.
@property (nonatomic, strong) RACCommand *rac_command;

@end
