//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "RACCommand+Private.h"
#import "RACSubscriber.h"

@interface RACCommand ()
@property (nonatomic, copy) BOOL (^canExecuteBlock)(id value);
@end


@implementation RACCommand

- (instancetype)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.canExecute = YES;
	
	return self;
}


#pragma mark API

@synthesize canExecute;
@synthesize canExecuteBlock;

+ (instancetype)command {
	return [self subject];
}

+ (instancetype)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock {
	RACCommand *command = [self command];
	if(executeBlock != NULL) [command subscribeNext:executeBlock];
	command.canExecuteBlock = canExecuteBlock;
	return command;
}

+ (instancetype)commandWithCanExecuteObservable:(id<RACSubscribable>)canExecuteObservable execute:(void (^)(id value))executeBlock {
	RACCommand *command = [self commandWithCanExecute:NULL execute:executeBlock];
	
	[canExecuteObservable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
		command.canExecute = [x boolValue];
	} error:NULL completed:NULL]];
	
	return command;
}

- (BOOL)canExecute:(id)value {
	if(self.canExecuteBlock != NULL) {
		return self.canExecuteBlock(value);
	}
	
	return self.canExecute;
}

- (void)execute:(id)value {
	[self sendNext:value];
}

@end
