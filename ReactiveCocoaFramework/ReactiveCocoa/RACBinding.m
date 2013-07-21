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

@interface RACBinding ()

// The signal of facts.
@property (nonatomic, strong, readonly) RACReplaySubject *factsSubject;

// The signal of rumors.
@property (nonatomic, strong, readonly) RACReplaySubject *rumorsSubject;

@end

@interface RACBindingEndpoint ()

// Initializes this endpoint for the given binding.
//
// The binding must already have valid factsSubject and rumorsSubject properties.
- (id)initWithBinding:(RACBinding *)binding;

@end

@implementation RACBinding

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_factsSubject = [RACReplaySubject replaySubjectWithCapacity:1];
	_factsSubject.name = @"factsSubject";

	_rumorsSubject = [RACReplaySubject replaySubjectWithCapacity:1];
	_rumorsSubject.name = @"rumorsSubject";

	// Propagate errors and completion to everything.
	[[self.factsSubject ignoreValues] subscribe:self.rumorsSubject];
	[[self.rumorsSubject ignoreValues] subscribe:self.factsSubject];

	_factsEndpoint = [[RACBindingFactsEndpoint alloc] initWithBinding:self];
	_rumorsEndpoint = [[RACBindingRumorsEndpoint alloc] initWithBinding:self];

	return self;
}

@end

@implementation RACBindingEndpoint

#pragma mark Lifecycle

- (id)init {
	NSCAssert(NO, @"%@ should not be instantiated directly. Create a RACBinding instead.", self.class);
	return nil;
}

- (id)initWithBinding:(RACBinding *)binding {
	NSCParameterAssert(binding != nil);
	NSCParameterAssert(binding.factsSubject != nil);
	NSCParameterAssert(binding.rumorsSubject != nil);

	return [super init];
}

@end

@implementation RACBindingRumorsEndpoint

- (id)initWithBinding:(RACBinding *)binding {
	self = [super initWithBinding:binding];
	if (self == nil) return nil;

	_factsSignal = binding.factsSubject;
	_rumorsSubscriber = binding.rumorsSubject;

	return self;
}

@end

@implementation RACBindingFactsEndpoint

- (id)initWithBinding:(RACBinding *)binding {
	self = [super initWithBinding:binding];
	if (self == nil) return nil;

	_rumorsSignal = binding.rumorsSubject;
	_factsSubscriber = binding.factsSubject;

	return self;
}

@end
