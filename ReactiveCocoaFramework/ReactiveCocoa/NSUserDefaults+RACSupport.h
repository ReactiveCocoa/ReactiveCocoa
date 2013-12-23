//
//  NSUserDefaults+RACSupport.h
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACChannelTerminal;

@interface NSUserDefaults (RACSupport)

// Creates and returns a terminal for binding the user defaults key.
//
// key - The user defaults key to create the channel terminal for.
//
// This makes it easy to bind a property to a default by assigning to
// `RACChannelTo`.
//
// The terminal will send the value of the user defaults key upon subscription.
//
// Returns a channel terminal.
- (RACChannelTerminal *)rac_channelTerminalForKey:(NSString *)key;

@end
