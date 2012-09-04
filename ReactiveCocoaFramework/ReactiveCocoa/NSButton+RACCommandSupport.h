//
//  NSButton+RACCommandSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACCommand;


@interface NSButton (RACCommandSupport)

// Sets the button's command. When the button is clicked, the command is
// executed with the sender of the event. The button's enabledness is bound
// to the command's `canExecute`.
//
// Note: this will reset the button's target and action.
@property (nonatomic, strong) RACCommand *rac_command;

@end
