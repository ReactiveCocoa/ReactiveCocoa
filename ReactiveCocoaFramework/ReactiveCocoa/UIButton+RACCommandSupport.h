//
//  UIButton+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Henrik Hodne on 6/13/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACCommand;

@interface UIButton (RACCommandSupport)

// Sets the control's command. When the control is clicked, the command is
// executed with the sender of the event. The control's enabledness is bound
// to the command's `canExecute`.
//
// Note: this will reset the control's target and action.
@property (nonatomic, strong) RACCommand *rac_command;

@end
