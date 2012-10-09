//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "RACSubscriber.h"

@interface RACCommand ()
@property (readwrite) BOOL canExecute;
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
	return [[self alloc] initWithCanExecuteSubscribable:nil block:NULL];
}

+ (instancetype)commandWithBlock:(void (^)(id value))executeBlock {
	return [[self alloc] initWithCanExecuteSubscribable:nil block:executeBlock];
}

+ (instancetype)commandWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable block:(void (^)(id sender))block {
	return [[self alloc] initWithCanExecuteSubscribable:canExecuteSubscribable block:block];
}

- (id)initWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable block:(void (^)(id sender))block {
	self = [self init];
	if (self == nil) return nil;
	
	if (block != NULL) [self subscribeNext:block];
		
	__weak id weakSelf = self;
	[canExecuteSubscribable subscribe:[RACSubscriber subscriberWithNext:^(NSNumber *x) {
		RACCommand *strongSelf = weakSelf;
		strongSelf.canExecute = x.boolValue;
	} error:NULL completed:NULL]];
		
	return self;
}

- (BOOL)execute:(id)sender {
	if (!self.canExecute) return NO;
	
	[self sendNext:sender];
	
	return YES;
}

@end
