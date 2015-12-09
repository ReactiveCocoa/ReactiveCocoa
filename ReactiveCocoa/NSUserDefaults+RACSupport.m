//
//  NSUserDefaults+RACSupport.m
//  ReactiveCocoa
//
//  Created by Matt Diephouse on 12/19/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSUserDefaults+RACSupport.h"
#import <ReactiveCocoa/EXTScope.h>
#import "NSNotificationCenter+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "RACChannel.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"

@implementation NSUserDefaults (RACSupport)

- (RACChannelTerminal *)rac_channelTerminalForKey:(NSString *)key {
	RACChannel *channel = [RACChannel new];
	
	RACScheduler *scheduler = [RACScheduler scheduler];
	__block BOOL ignoreNextValue = NO;
	
	@weakify(self);
	[[[[[[[NSNotificationCenter.defaultCenter
		rac_addObserverForName:NSUserDefaultsDidChangeNotification object:self]
		map:^(id _) {
			@strongify(self);
			return [self objectForKey:key];
		}]
		startWith:[self objectForKey:key]]
		// Don't send values that were set on the other side of the terminal.
		filter:^ BOOL (id _) {
			if (RACScheduler.currentScheduler == scheduler && ignoreNextValue) {
				ignoreNextValue = NO;
				return NO;
			}
			return YES;
		}]
		distinctUntilChanged]
		takeUntil:self.rac_willDeallocSignal]
		subscribe:channel.leadingTerminal];
	
	[[channel.leadingTerminal
		deliverOn:scheduler]
		subscribeNext:^(id value) {
			@strongify(self);
			ignoreNextValue = YES;
			[self setObject:value forKey:key];
		}];
	
	return channel.followingTerminal;
}

@end
