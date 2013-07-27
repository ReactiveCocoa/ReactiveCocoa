//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACUnit.h"

@interface RACBindingTerminal ()

// The values for this terminal.
@property (nonatomic, strong, readonly) RACSignal *values;

// A subscriber will will send values to the other terminal.
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;

- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

@implementation RACBinding

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	RACReplaySubject *leadingSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"leadingSubject"];
	RACReplaySubject *followingSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"followingSubject"];

	// Propagate errors and completion to everything.
	[[leadingSubject ignoreValues] subscribe:followingSubject];
	[[followingSubject ignoreValues] subscribe:leadingSubject];

	// We don't want any starting value from the leadingSubject, but we do want
	// error and completion to be replayed, so we just start it off with a dummy
	// value, and always skip the initial `next` event.
	[leadingSubject sendNext:RACUnit.defaultUnit];
	RACSignal *leadingValues = [leadingSubject skip:1];

	_leadingTerminal = [[[RACBindingTerminal alloc] initWithValues:leadingValues otherTerminal:followingSubject] setNameWithFormat:@"leadingTerminal"];
	_followingTerminal = [[[RACBindingTerminal alloc] initWithValues:followingSubject otherTerminal:leadingSubject] setNameWithFormat:@"followingTerminal"];

	return self;
}

@end

@implementation RACBindingTerminal

#pragma mark Lifecycle

- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal {
	NSCParameterAssert(values != nil);
	NSCParameterAssert(otherTerminal != nil);

	self = [super init];
	if (self == nil) return nil;

	_values = values;
	_otherTerminal = otherTerminal;

	return self;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.values subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.otherTerminal sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.otherTerminal sendError:error];
}

- (void)sendCompleted {
	[self.otherTerminal sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.otherTerminal didSubscribeWithDisposable:disposable];
}

@end
