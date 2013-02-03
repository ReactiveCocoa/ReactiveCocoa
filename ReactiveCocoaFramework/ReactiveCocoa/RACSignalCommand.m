//
//  RACSignalCommand.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalCommand.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACSignal+Operations.h"

@interface RACSignalCommand () {
	RACSubject *_signalBlockSignal;
}

@property (atomic, assign, readwrite, getter = isExecuting) BOOL executing;
@property (nonatomic, copy, readonly) RACSignal * (^signalBlock)(id);

@end

@implementation RACSignalCommand

#pragma mark Lifecycle

+ (instancetype)commandWithSignalBlock:(RACSignal * (^)(id sender))signalBlock {
	return [self commandWithCanExecuteSignal:nil signalBlock:signalBlock];
}

+ (instancetype)commandWithCanExecuteSignal:(RACSignal *)canExecuteSignal signalBlock:(RACSignal * (^)(id sender))signalBlock {
	return [[self alloc] initWithCanExecuteSignal:canExecuteSignal signalBlock:signalBlock];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_signalBlockSignal = [RACSubject subject];

	return self;
}

- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal signalBlock:(RACSignal * (^)(id sender))signalBlock {
	canExecuteSignal = (canExecuteSignal == nil ? [RACSignal return:@YES] : [canExecuteSignal startWith:@YES]);

	RACSignal *combinedCanExecuteSignal = [RACSignal combineLatest:@[
		RACAbleWithStart(self.executing),
		canExecuteSignal
	] reduce:^(NSNumber *executing, NSNumber *canExecute) {
		return @(!executing.boolValue && canExecute.boolValue);
	}];

	self = [self initWithCanExecuteSignal:combinedCanExecuteSignal block:nil];
	if (self == nil) return nil;

	_signalBlock = [signalBlock copy];

	return self;
}

#pragma mark RACCommand

- (BOOL)execute:(id)sender {
	// Synchronize checking `canExecute` and setting `executing` because the
	// latter informs the former, and we need it to change atomically.
	//
	// This is the only critical section in this code because we only need to
	// flip it to YES atomically. There's no race between threads setting it to
	// NO.
	@synchronized (self) {
		if (!self.canExecute) return NO;
		self.executing = YES;
	}

	RACSignal *signal;

	if (self.signalBlock != nil) {
		signal = self.signalBlock(sender);
		NSAssert(signal != nil, @"signalBlock for %@ returned nil", self);

		[_signalBlockSignal sendNext:signal];
	} else {
		signal = [RACSignal return:sender];
	}

	[signal subscribeNext:^(id x) {
		[self sendNext:x];
	} error:^(NSError *error) {
		[self sendError:error];
		self.executing = NO;
	} completed:^{
		self.executing = NO;
	}];
	
	return YES;
}

@end
