//
//  RACSignalSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignalSequence.h"
#import "RACConnectableSignal.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"

@interface RACSignalSequence ()

// Replays the signal given on initialization.
@property (nonatomic, strong, readonly) RACReplaySubject *subject;

@end

@implementation RACSignalSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithSignal:(RACSignal *)signal {
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
	id value = [self.subject firstOrDefault:self];

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
	return self.subject.toArray;
}

#pragma mark NSObject

- (NSString *)description {
	// Synchronously accumulate the values that have been sent so far.
	NSMutableArray *values = [NSMutableArray array];
	RACDisposable *disposable = [self.subject subscribeNext:^(id value) {
		@synchronized (values) {
			[values addObject:value ?: NSNull.null];
		}
	}];

	[disposable dispose];

	return [NSString stringWithFormat:@"<%@: %p>{ values = %@ … }", self.class, self, values];
}

@end
