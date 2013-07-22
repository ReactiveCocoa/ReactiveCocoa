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

@interface RACBinding () {
	// Contains all of the facts.
	RACReplaySubject *_factsSubject;

	// Contains all of the rumors.
	RACReplaySubject *_rumorsSubject;
}

@end

@implementation RACBinding

#pragma mark Properties

- (RACSignal *)factsSignal {
	return _factsSubject;
}

- (id<RACSubscriber>)factsSubscriber {
	return _factsSubject;
}

- (RACSignal *)rumorsSignal {
	return _rumorsSubject;
}

- (id<RACSubscriber>)rumorsSubscriber {
	return _rumorsSubject;
}

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_factsSubject = [RACReplaySubject replaySubjectWithCapacity:1];
	_factsSubject.name = @"factsSubject";

	_rumorsSubject = [RACReplaySubject replaySubjectWithCapacity:1];
	_rumorsSubject.name = @"rumorsSubject";

	// Propagate errors and completion to everything.
	[[self.factsSignal ignoreValues] subscribe:self.rumorsSubscriber];
	[[self.rumorsSignal ignoreValues] subscribe:self.factsSubscriber];

	return self;
}

@end
