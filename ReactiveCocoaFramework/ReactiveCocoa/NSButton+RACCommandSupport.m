//
//  NSButton+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSButton+RACCommandSupport.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"

#import <objc/runtime.h>

static void * NSButtonRACCommandsKey = &NSButtonRACCommandsKey;

@interface NSButton ()
@property (nonatomic, readonly) NSMutableArray *commands;
@end


@implementation NSButton (RACCommandSupport)

- (void)addCommand:(RACCommand *)command {
	NSParameterAssert(command != nil);
	
	[self.commands addObject:command];
	
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
		if([command canExecute:sender]) {
			[command execute:sender];
		}
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

@end
