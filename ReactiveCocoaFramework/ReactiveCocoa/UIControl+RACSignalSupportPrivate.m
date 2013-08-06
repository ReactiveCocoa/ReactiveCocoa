//
//  UIControl+RACSignalSupportPrivate.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 06/08/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSignalSupportPrivate.h"
#import "EXTScope.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACLifting.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "UIControl+RACSignalSupport.h"

@implementation UIControl (RACSignalSupportPrivate)

- (RACChannelTerminal *)rac_channelForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key nilValue:(id)nilValue {
	NSCParameterAssert(key.length > 0);
	key = [key copy];
	RACChannel *channel = [[RACChannel alloc] init];

	[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		[channel.followingTerminal sendCompleted];
	}]];

	RACSignal *eventSignal = [[self rac_signalForControlEvents:controlEvents] mapReplace:key];
	[[self
    rac_liftSelector:@selector(valueForKey:) withSignals:eventSignal, nil]
	 subscribe:channel.followingTerminal];

	@weakify(self);

	SEL selector = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:animated:", [key substringToIndex:1].uppercaseString, [key substringFromIndex:1]]);
	NSInvocation *invocation = nil;
	if ([self respondsToSelector:selector]) {
		invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
		invocation.selector = selector;
		invocation.target = self;
	}

	[channel.followingTerminal subscribeNext:^(id x) {
		@strongify(self);

		if (invocation == nil) {
			[self setValue:x ?: nilValue forKey:key];
			return;
		}

		id value = x ?: nilValue;
		[invocation rac_setArgument:value atIndex:2];

		BOOL animated = YES;
		[invocation setArgument:&animated atIndex:3];

		[invocation invoke];
	}];

	return channel.leadingTerminal;
}

@end
