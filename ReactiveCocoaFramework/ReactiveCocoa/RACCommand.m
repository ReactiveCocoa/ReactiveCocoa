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
@property (nonatomic, readonly, copy) BOOL (^canExecuteBlock)(id value);
@end


@implementation RACCommand

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_canExecute = YES;
	
	return self;
}


#pragma mark API

+ (instancetype)command {
	return [self subject];
}

+ (instancetype)commandWithCanExecute:(BOOL (^)(id value))canExecuteBlock execute:(void (^)(id value))executeBlock {
	return [[self alloc] initWithExecutionBlock:executeBlock canExecuteBlock:canExecuteBlock canExecuteSubscribable:nil];
}

+ (instancetype)commandWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable execute:(void (^)(id value))executeBlock {
	return [[self alloc] initWithExecutionBlock:executeBlock canExecuteBlock:NULL canExecuteSubscribable:canExecuteSubscribable];
}

+ (instancetype)commandWithExecuteBlock:(void (^)(id value))executeBlock {
	return [[self alloc] initWithExecutionBlock:executeBlock canExecuteBlock:NULL canExecuteSubscribable:nil];
}

- (id)initWithExecutionBlock:(void (^)(id value))block canExecuteBlock:(BOOL (^)(id value))canExecuteBlock canExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable {
	self = [self init];
	if (self == nil) return nil;
	
	if (block != NULL) [self subscribeNext:block];
	
	_canExecuteBlock = [canExecuteBlock copy];
	
	__unsafe_unretained id weakSelf = self;
	[canExecuteSubscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
		RACCommand *strongSelf = weakSelf;
		strongSelf.canExecute = [x boolValue];
	} error:NULL completed:NULL]];
		
	return self;
}

- (BOOL)canExecute:(id)value {
	if (self.canExecuteBlock == NULL) return YES;
	
	return self.canExecuteBlock(value);
}

- (void)execute:(id)value {
	[self sendNext:value];
}

- (BOOL)executeIfAllowed:(id)value {
	if (![self canExecute:value] || !self.canExecute) return NO;
	
	[self execute:value];
	
	return YES;
}

@end
