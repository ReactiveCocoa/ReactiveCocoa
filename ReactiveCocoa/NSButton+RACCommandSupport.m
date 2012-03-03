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
@property (nonatomic, strong) RACObservableValue *enabledValue;
@end


@implementation NSButton (RACCommandSupport)

- (void)addCommand:(RACCommand *)command {
	[self.commands addObject:command];
	
	self.enabledValue = [RACObservableValue value];
	[[RACObservableValue 
		whenAny:[self.commands valueForKey:@"canExecute"]
		reduce:^(NSArray *x) {
			BOOL enabled = YES;
			for(id v in x) {
				enabled = enabled && [v boolValue];
			}
		
			return [NSNumber numberWithBool:enabled];
		}]
		toProperty:self.enabledValue];
	
	[self bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.enabledValue.value)];
	
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
		command.value = sender;
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

- (void)setEnabledValue:(RACObservableValue *)ev {
	objc_setAssociatedObject(self, NSButtonRACEnabledValueKey, ev, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RACObservableValue *)enabledValue {
	return objc_getAssociatedObject(self, NSButtonRACEnabledValueKey);
}

@end
