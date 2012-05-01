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

// Adds the given command to the button. The command's `canExecuteValue`
// controls the button's enabledness. The command's `-canExecute:` and
// `-execute:` are passed the action's sender.
//
// Note: this will reset the button's target and action.
//
// command - the command to add. Cannot be nil.
- (void)addCommand:(RACCommand *)command;

@end
