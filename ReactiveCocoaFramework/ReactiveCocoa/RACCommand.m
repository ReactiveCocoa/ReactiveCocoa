//
//  RACCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "RACSubscriptingAssignmentTrampoline.h"

@interface RACCommand ()
@property (readwrite) BOOL canExecute;
@end

@implementation RACCommand

#pragma mark Lifecycle

+ (instancetype)command {
	return [[self alloc] initWithCanExecuteSignal:nil block:NULL];
}

+ (instancetype)commandWithBlock:(void (^)(id value))executeBlock {
	return [[self alloc] initWithCanExecuteSignal:nil block:executeBlock];
}

+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal block:(void (^)(id sender))block {
	return [[self alloc] initWithCanExecuteSignal:canExecuteSignal block:block];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_canExecute = YES;
	
	return self;
}

- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal block:(void (^)(id sender))block {
	self = [self init];
	if (self == nil) return nil;
	
	if (block != NULL) [self subscribeNext:block];
	
	RAC(self.canExecute) = canExecuteSignal;
	return self;
}

- (BOOL)execute:(id)sender {
	if (!self.canExecute) return NO;
	
	[self sendNext:sender];
	
	return YES;
}

@end
