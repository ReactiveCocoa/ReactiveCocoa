//
//  RACAction.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"

@interface RACAction () {
	RACSubject *_errors;

	// Although RACReplaySubject is deprecated for consumers, we're going to use it
	// internally for the foreseeable future. We just want to expose something
	// higher level.
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	RACReplaySubject *_executing;
	#pragma clang diagnostic pop
}

// The signal that the receiver was initialized with, shared so that
// simultaneous executions receive the same values.
@property (nonatomic, strong, readonly) RACSignal *sharedSignal;

@end

@implementation RACAction

#pragma mark Lifecycle

- (id)init {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithSignal:(RACSignal *)signal {
	NSCParameterAssert(signal != nil);

	self = [super init];
	if (self == nil) return nil;

	// Use temporaries for these subjects so we don't have to weakly reference
	// `self` in the signal chain below. (Weak references are expensive.)
	RACSubject *errors = [[RACSubject subject] setNameWithFormat:@"[%@] -errors", self.sharedSignal.name];

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	RACReplaySubject *executing = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"[%@] -executing", self.sharedSignal.name];
	#pragma clang diagnostic pop

	// Not executing by default.
	[executing sendNext:@NO];

	_errors = errors;
	_executing = executing;

	_sharedSignal = [[[[[[RACSignal
		defer:^{
			[executing sendNext:@YES];
			return signal;
		}]
		subscribeOn:RACScheduler.mainThreadScheduler]
		doDisposed:^{
			[RACScheduler.mainThreadScheduler schedule:^{
				[executing sendNext:@NO];
			}];
		}]
		doError:^(NSError *error) {
			[RACScheduler.mainThreadScheduler schedule:^{
				[errors sendNext:error];
			}];
		}]
		shareWhileActive]
		setNameWithFormat:@"[%@] -action", signal.name];

	return self;
}

- (void)dealloc {
	RACSubject *errors = _errors;
	RACSubject *executing = _executing;

	[RACScheduler.mainThreadScheduler schedule:^{
		[errors sendCompleted];
		[executing sendCompleted];
	}];
}

#pragma mark Execution

- (void)execute:(id)sender {
	[self.sharedSignal subscribe:nil];
}

- (RACSignal *)deferred {
	return self.sharedSignal;
}

@end

@implementation RACSignal (RACActionAdditions)

- (RACAction *)action {
	return [[RACAction alloc] initWithSignal:self];
}

@end
