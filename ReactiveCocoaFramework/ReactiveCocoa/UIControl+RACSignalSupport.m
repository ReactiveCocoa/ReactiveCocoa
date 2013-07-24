//
//  UIControl+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSignalSupport.h"
#import "EXTScope.h"
#import "RACBinding+Private.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber+Private.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"

@implementation UIControl (RACSignalSupport)

- (RACSignal *)rac_signalForControlEvents:(UIControlEvents)controlEvents {
	@weakify(self);

	return [[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			[self addTarget:subscriber action:@selector(sendNext:) forControlEvents:controlEvents];
			[self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[subscriber sendCompleted];
			}]];

			return [RACDisposable disposableWithBlock:^{
				@strongify(self);
				[self removeTarget:subscriber action:@selector(sendNext:) forControlEvents:controlEvents];
			}];
		}]
		setNameWithFormat:@"%@ -rac_signalForControlEvents: %lx", [self rac_description], (unsigned long)controlEvents];
}

- (RACBinding *)rac_bindingForControlEvents:(UIControlEvents)controlEvents key:(NSString *)key nilValue:(id)nilValue {
	@weakify(self);

	RACBinding *binding = [[RACBinding alloc] init];
	if (binding == nil) return nil;

	binding.signal = [RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			[subscriber sendNext:[self valueForKey:key]];
			return [[[self
				rac_signalForControlEvents:controlEvents]
				map:^(id sender) {
					return [sender valueForKey:key];
				}]
				subscribe:subscriber];
		}];

	SEL selector = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:animated:", [key substringToIndex:1].uppercaseString, [key substringFromIndex:1]]);
	NSInvocation *invocation = nil;
	if ([self respondsToSelector:selector]) {
		invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
		invocation.selector = selector;
		invocation.target = self;
	}

	binding.subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(self);
		if (self == nil) return;

		if (invocation == nil) {
			[self setValue:x ?: nilValue forKey:key];
			return;
		}

		id value = x ?: nilValue;
		[invocation rac_setArgument:value atIndex:2];

		BOOL animated = YES;
		[invocation setArgument:&animated atIndex:3];

		[invocation invoke];
	} error:^(NSError *error) {
		@strongify(self);

		NSCAssert(NO, @"Received error from %@ in binding for control events: %lx key \"%@\": %@", self, (unsigned long)controlEvents, key, error);
		// Log the error if we're running with assertions disabled.
		NSLog( @"Received error from %@ in binding for control events: %lx key \"%@\": %@", self, (unsigned long)controlEvents, key, error);

	} completed:nil];

	return binding;
}

@end
