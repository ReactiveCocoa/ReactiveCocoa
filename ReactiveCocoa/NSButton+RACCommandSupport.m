//
//  NSButton+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSButton+RACCommandSupport.h"
#import "NSObject+RACPropertyObserving.h"
#import "RACCommand.h"

#import <objc/runtime.h>

static void * NSButtonRACCommandsKey = &NSButtonRACCommandsKey;
static void * NSButtonRACEnabledValueKey = &NSButtonRACEnabledValueKey;

@interface NSButton ()
@property (nonatomic, readonly) NSMutableArray *commands;
@property (nonatomic, strong) RACValue *enabledValue;
@end


@implementation NSButton (RACCommandSupport)

- (void)addCommand:(RACCommand *)command {
	[self.commands addObject:command];
	
	self.enabledValue = [RACValue value];
	[[[RACValue 
		combineLatest:[self.commands valueForKey:@"canExecuteValue"]]
		select:^(NSArray *x) {
			BOOL enabled = YES;
			for(id v in x) {
				enabled = enabled && [v boolValue];
			}
		
			return [NSNumber numberWithBool:enabled];
		}]
		toProperty:self.enabledValue];
	
	[self bind:NSEnabledBinding toValue:self.enabledValue];
	[self setEnabled:[self.enabledValue.value boolValue]];
	
	[self hijackActionAndTargetIfNeeded];
}

- (void)hijackActionAndTargetIfNeeded {
	SEL hijackSelector = @selector(RACCommandsPerformAction:);
	if([self target] != self || [self action] != hijackSelector) {
		if([self action] != NULL) NSLog(@"WARNING: -[NSButton addCommand:] hijacks the button's existing target and action.");
		
		[self setTarget:self];
		[self setAction:hijackSelector];
	}
}

- (void)RACCommandsPerformAction:(id)sender {
	for(RACCommand *command in self.commands) {
		[command execute:sender];
	}
}

- (NSMutableArray *)commands {
	NSMutableArray *c = objc_getAssociatedObject(self, NSButtonRACCommandsKey);
	if(c == nil) {
		c = [NSMutableArray array];
		objc_setAssociatedObject(self, NSButtonRACCommandsKey, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return c;
}

- (void)setEnabledValue:(RACValue *)ev {
	objc_setAssociatedObject(self, NSButtonRACEnabledValueKey, ev, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RACValue *)enabledValue {
	return objc_getAssociatedObject(self, NSButtonRACEnabledValueKey);
}

@end
