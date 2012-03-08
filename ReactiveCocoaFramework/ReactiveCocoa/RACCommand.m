//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACCommand.h"
#import "RACCommand+Private.h"
#import "RACSequence+Private.h"

@interface RACCommand ()
@property (nonatomic, strong) RACValue *canExecuteValue;
@end


@implementation RACCommand

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.canExecuteValue = [RACValue valueWithValue:[NSNumber numberWithBool:YES]];
	
	return self;
}


#pragma mark API

@synthesize canExecuteValue;
@synthesize canExecuteBlock;
@synthesize executeBlock;

+ (id)command {
	return [self value];
}

+ (id)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock {
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
	
	if(self.executeBlock != NULL) {
		self.executeBlock(value);
	}
}

@end
