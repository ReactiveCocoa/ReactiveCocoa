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
@property (nonatomic, copy) BOOL (^canExecuteBlock)(id value);
@property (nonatomic, copy) void (^executeBlock)(id value);
@end


@implementation RACCommand

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.canExecute = YES;
	
	return self;
}


#pragma mark API

@synthesize canExecute;
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
	
	return self.canExecute;
}

- (void)execute:(id)value {	
	self.value = value;
	
	if(self.executeBlock != NULL) {
		self.executeBlock(value);
	}
}

@end
