//
//  RACAction.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"
#import "RACAction+Private.h"
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

#pragma mark Properties

- (RACSignal *)errors {
	return [[_errors
		deliverOn:RACScheduler.mainThreadScheduler]
		setNameWithFormat:@"[%@] -errors", self.sharedSignal.name];
}

- (RACSignal *)executing {
	return [_executing
		setNameWithFormat:@"[%@] -executing", self.sharedSignal.name];
}

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
	RACSubject *errors = [RACSubject subject];

	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	RACReplaySubject *executing = [RACReplaySubject replaySubjectWithCapacity:1];
	#pragma clang diagnostic pop

	// Not executing by default.
	[executing sendNext:@NO];

	_errors = errors;
	_executing = executing;

	_sharedSignal = [[[[[[signal
		initially:^{
			[executing sendNext:@YES];
		}]
		subscribeOn:RACScheduler.mainThreadScheduler]
		finally:^{
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

+ (instancetype)actionWithBlock:(BOOL (^)(NSError **))actionBlock {
	RACSignal *signal = [[RACSignal
		defer:^{
			NSError *error = nil;
			BOOL success = actionBlock(&error);
			if (success) {
				return [RACSignal empty];
			} else {
				return [RACSignal error:error];
			}
		}]
		setNameWithFormat:@"+actionWithBlock:"];
	
	return [[self alloc] initWithSignal:signal];
}

- (void)dealloc {
	[_errors sendCompleted];
	[_executing sendCompleted];
}

#pragma mark Execution

- (void)execute:(id)sender {
	[self.sharedSignal subscribeCompleted:^{}];
}

- (RACSignal *)deferred {
	return self.sharedSignal;
}

@end
