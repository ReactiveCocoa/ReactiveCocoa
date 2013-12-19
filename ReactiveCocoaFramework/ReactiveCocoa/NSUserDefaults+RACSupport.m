//
//  NSUserDefaults+RACSupport.m
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSUserDefaults+RACSupport.h"

#import "EXTScope.h"
#import "RACChannel.h"
#import "NSNotificationCenter+RACSupport.h"
#import "NSObject+RACLifting.h"

@implementation NSUserDefaults (RACSupport)

- (RACChannelTerminal *)rac_channelTerminalForKey:(NSString *)key {
	RACChannel *channel = [RACChannel new];
	
	@weakify(self);
	[[[[[NSNotificationCenter.defaultCenter
		rac_addObserverForName:NSUserDefaultsDidChangeNotification object:self]
		map:^(id _) {
			@strongify(self);
			return [self objectForKey:key];
		}]
		startWith:[self objectForKey:key]]
		distinctUntilChanged]
		subscribe:channel.leadingTerminal];
	
	[self rac_liftSelector:@selector(setObject:forKey:) withSignals:channel.leadingTerminal, [RACSignal return:key], nil];
	
	return channel.followingTerminal;
}

@end
