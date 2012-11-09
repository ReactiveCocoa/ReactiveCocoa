//
//  RACSubscribableSequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribableSequence.h"
#import "RACConnectableSubscribable.h"
#import "RACReplaySubject.h"
#import "RACSubscribableProtocol.h"

@interface RACSubscribableSequence ()

// Replays the subscribable given on initialization.
@property (nonatomic, strong, readonly) RACReplaySubject *subject;

@end

@implementation RACSubscribableSequence

#pragma mark Lifecycle

+ (RACSequence *)sequenceWithSubscribable:(id<RACSubscribable>)subscribable {
	RACSubscribableSequence *seq = [[self alloc] init];

	RACReplaySubject *subject = [RACReplaySubject subject];
	[subscribable subscribeNext:^(id value) {
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
	return [self.class sequenceWithSubscribable:[self.subject skip:1]];
}

- (NSArray *)array {
	return self.subject.toArray;
}

@end
