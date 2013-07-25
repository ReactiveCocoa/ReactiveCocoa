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

@interface RACBindingEndpoint ()

// The values for this endpoint.
@property (nonatomic, strong, readonly) RACSignal *values;

// A subscriber will will send values to the other endpoint.
@property (nonatomic, strong, readonly) id<RACSubscriber> otherEndpoint;

- (id)initWithValues:(RACSignal *)values otherEndpoint:(id<RACSubscriber>)otherEndpoint;

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

	_leadingEndpoint = [[[RACBindingEndpoint alloc] initWithValues:leadingValues otherEndpoint:followingSubject] setNameWithFormat:@"leadingEndpoint"];
	_followingEndpoint = [[[RACBindingEndpoint alloc] initWithValues:followingSubject otherEndpoint:leadingSubject] setNameWithFormat:@"followingEndpoint"];

	return self;
}

@end

@implementation RACBindingEndpoint

#pragma mark Lifecycle

- (id)initWithValues:(RACSignal *)values otherEndpoint:(id<RACSubscriber>)otherEndpoint {
	NSCParameterAssert(values != nil);
	NSCParameterAssert(otherEndpoint != nil);

	self = [super init];
	if (self == nil) return nil;

	_values = values;
	_otherEndpoint = otherEndpoint;

	return self;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.values subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.otherEndpoint sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.otherEndpoint sendError:error];
}

- (void)sendCompleted {
	[self.otherEndpoint sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.otherEndpoint didSubscribeWithDisposable:disposable];
}

@end
