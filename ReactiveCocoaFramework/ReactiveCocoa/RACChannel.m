//
//  RACChannel.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACChannel.h"
#import "RACDisposable.h"
#import "RACLiveSubscriber.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACSignal+Private.h"

@interface RACChannelTerminal ()

// The values for this terminal.
@property (nonatomic, strong, readonly) RACSignal *values;

// A subscriber will will send values to the other terminal.
@property (nonatomic, strong, readonly) id<RACSubscriber> otherTerminal;

- (id)initWithValues:(RACSignal *)values otherTerminal:(id<RACSubscriber>)otherTerminal;

@end

@implementation RACChannel

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	// Although RACReplaySubject is deprecated for consumers, we're going to use it
	// internally for the foreseeable future. We just want to expose something
	// higher level.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"

	// We don't want any starting value from the leadingSubject, but we do want
	// error and completion to be replayed.
	RACReplaySubject *leadingSubject = [[RACReplaySubject replaySubjectWithCapacity:0] setNameWithFormat:@"leadingSubject"];
	RACReplaySubject *followingSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"followingSubject"];

	#pragma clang diagnostic pop

	// Propagate errors and completion to everything.
	[[leadingSubject ignoreValues] subscribe:followingSubject];
	[[followingSubject ignoreValues] subscribe:leadingSubject];

	_leadingTerminal = [[[RACChannelTerminal alloc] initWithValues:leadingSubject otherTerminal:followingSubject] setNameWithFormat:@"leadingTerminal"];
	_followingTerminal = [[[RACChannelTerminal alloc] initWithValues:followingSubject otherTerminal:leadingSubject] setNameWithFormat:@"followingTerminal"];

	return self;
}

@end

@implementation RACChannelTerminal

#pragma mark Properties

- (RACCompoundDisposable *)disposable {
	return self.otherTerminal.disposable;
}

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

- (void)attachSubscriber:(RACLiveSubscriber *)subscriber {
	[self.values attachSubscriber:subscriber];
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

@end
