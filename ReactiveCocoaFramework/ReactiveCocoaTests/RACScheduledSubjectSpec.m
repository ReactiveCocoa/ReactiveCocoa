//
//  RACScheduledSubjectSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACScheduledSubject.h"
#import "RACScheduler.h"

SpecBegin(RACScheduledSubject)

__block RACScheduledSubject *subject;
__block RACScheduler *scheduler;

beforeEach(^{
	scheduler = [RACScheduler scheduler];
	subject = [RACScheduledSubject subjectWithScheduler:scheduler];
});

it(@"should send nexts on the given scheduler", ^{
	__block RACScheduler *currentScheduler;
	[subject subscribeNext:^(id _) {
		currentScheduler = RACScheduler.currentScheduler;
	}];

	[subject sendNext:@42];
	expect(currentScheduler).will.equal(scheduler);
});

it(@"should send error on the given scheduler", ^{
	__block RACScheduler *currentScheduler;
	[subject subscribeError:^(NSError *error) {
		currentScheduler = RACScheduler.currentScheduler;
	}];

	[subject sendError:nil];
	expect(currentScheduler).will.equal(scheduler);
});

it(@"should send completed on the given scheduler", ^{
	__block RACScheduler *currentScheduler;
	[subject subscribeCompleted:^{
		currentScheduler = RACScheduler.currentScheduler;
	}];

	[subject sendCompleted];
	expect(currentScheduler).will.equal(scheduler);
});

SpecEnd
