//
//  RACSubjectSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriberExamples.h"

#import <libkern/OSAtomic.h>
#import "EXTScope.h"
#import "RACDisposable.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

SpecBegin(RACSubject)

__block RACSubject *subject;
__block NSMutableArray *values;

__block BOOL success;
__block NSError *error;

beforeEach(^{
	values = [NSMutableArray array];

	subject = [RACSubject subject];
	success = YES;
	error = nil;

	[subject subscribeNext:^(id value) {
		[values addObject:value];
	} error:^(NSError *e) {
		error = e;
		success = NO;
	} completed:^{
		success = YES;
	}];
});

itShouldBehaveLike(RACSubscriberExamples, ^{
	return @{
		RACSubscriberExampleSubscriber: subject,
		RACSubscriberExampleValuesReceivedBlock: [^{ return [values copy]; } copy],
		RACSubscriberExampleErrorReceivedBlock: [^{ return error; } copy],
		RACSubscriberExampleSuccessBlock: [^{ return success; } copy]
	};
});

SpecEnd
