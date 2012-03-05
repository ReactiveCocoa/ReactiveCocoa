//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACCommand.h"
#import "RACSequence+Private.h"

@interface RACCommand ()
@property (nonatomic, copy) BOOL (^canExecuteBlock)(id value);
@property (nonatomic, copy) void (^executeBlock)(id value);
@end


@implementation RACCommand


#pragma mark API

@synthesize canExecuteValue;
@synthesize canExecuteBlock;
@synthesize executeBlock;

+ (RACCommand *)command {
	return [self value];
}

+ (RACCommand *)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock {
	RACCommand *command = [self command];
	command.canExecuteBlock = canExecuteBlock;
	command.executeBlock = executeBlock;
	return command;
}

- (BOOL)canExecute:(id)value {
	if(self.canExecuteBlock != NULL) {
		return self.canExecuteBlock(value);
	}
	
	return [self.canExecuteValue.value boolValue];
}

- (void)execute:(id)value {
	if(![self canExecute:value]) return;
	
	self.value = value;
	[self sendCompletedToAllObservers];
	
	if(self.executeBlock != NULL) {
		self.executeBlock(value);
	}
}

@end
