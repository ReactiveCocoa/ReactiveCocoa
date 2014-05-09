//
//  NSUserDefaults+RACSupport.h
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"

@class RACChannelTerminal;
@class RACSignal;

@interface NSUserDefaults (RACSupport)

/// Observes the given user defaults key for changes.
///
/// key - The user defaults key to watch for changes. Must not be nil.
///
/// Returns a signal that sends the current value of the given key upon
/// subscription, then sends an updated value whenever the default changes.
- (RACSignal *)rac_objectsForKey:(NSString *)key;

@end

@interface NSUserDefaults (RACSupportDeprecated)

- (RACChannelTerminal *)rac_channelTerminalForKey:(NSString *)key RACDeprecated("Use -rac_objectsForKey: and -setObject:forKey: instead");

@end
