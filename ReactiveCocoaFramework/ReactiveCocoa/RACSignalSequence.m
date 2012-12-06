//
//  RACSignalSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignalSequence.h"
#import "RACConnectableSignal.h"
#import "RACReplaySubject.h"
#import "RACSignalProtocol.h"

@interface RACSignalSequence ()

// Replays the signal given on initialization.
@property (nonatomic, strong, readonly) RACReplaySubject *subject;

@end

@implementation RACSignalSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithSignal:(id<RACSignal>)signal {
	RACSignalSequence *seq = [[self alloc] init];

	RACReplaySubject *subject = [RACReplaySubject subject];
	[signal subscribeNext:^(id value) {
		[subject sendNext:value];
	} error:^(NSError *error) {
		[subject sendError:error];
	} completed:^{
		[subject sendCompleted];
	}];

	seq->_subject = subject;
	return seq;
}

#pragma mark RACSequence

- (id)head {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = @"com.github.ReactiveCocoa.RACSignalSequence";

	__block id value = self;
	__block BOOL done = NO;

	[self.subject subscribeNext:^(id x) {
		[condition lock];
		if (!done) {
			value = x;
			done = YES;
		}

		[condition signal];
		[condition unlock];
	} error:^(NSError *error) {
		[condition lock];
		done = YES;
		[condition signal];
		[condition unlock];
	} completed:^{
		[condition lock];
		done = YES;
		[condition signal];
		[condition unlock];
	}];

	[condition lock];
	while (!done) {
		[condition wait];
	}

	[condition unlock];

	if (value == self) {
		return nil;
	} else {
		return value ?: NSNull.null;
	}
}

- (RACSequence *)tail {
	return [self.class sequenceWithSignal:[self.subject skip:1]];
}

- (NSArray *)array {
	NSCondition *condition = [[NSCondition alloc] init];
	condition.name = @"com.github.ReactiveCocoa.RACSignalSequence";

	NSMutableArray *values = [NSMutableArray array];
	__block BOOL done = NO;

	[self.subject subscribeNext:^(id x) {
		[condition lock];
		[values addObject:x];
		[condition unlock];
	} error:^(NSError *error) {
		[condition lock];
		done = YES;
		[condition signal];
		[condition unlock];
	} completed:^{
		[condition lock];
		done = YES;
		[condition signal];
		[condition unlock];
	}];

	[condition lock];
	while (!done) {
		[condition wait];
	}

	[condition unlock];
	return [values copy];
}

@end
